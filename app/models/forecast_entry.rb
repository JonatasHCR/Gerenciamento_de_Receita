class ForecastEntry < ApplicationRecord
  has_paper_trail

  belongs_to :cost_center

  validates :month_year, presence: true, uniqueness: { scope: :cost_center_id }
  validates :forecasted_total, numericality: { greater_than_or_equal_to: 0 }
  validates :realized_total, numericality: { greater_than_or_equal_to: 0 }

  # realized_total é derivado do faturamento (NFs emitidas no mês do CC).
  before_validation :set_realized_from_invoices, on: :create

  scope :for_month, ->(month_year) { where(month_year: month_year) }
  scope :ordered, -> { joins(:cost_center).order("cost_centers.cr_code") }

  PT_MONTHS = %w[JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO].freeze

  # Date → "JUNHO/2026"
  def self.month_year_for(date)
    "#{PT_MONTHS[date.month - 1]}/#{date.year}"
  end

  # "JUNHO/2026" → intervalo de datas do mês (ou nil se formato inválido)
  def period_range
    parts = month_year.to_s.split("/")
    idx   = PT_MONTHS.index(parts[0].to_s.upcase)
    return nil unless idx && parts[1].present?

    start = Date.new(parts[1].to_i, idx + 1, 1)
    start.beginning_of_month..start.end_of_month
  rescue ArgumentError
    nil
  end

  # Soma das NFs emitidas no mês para o centro de custo (o "realizado").
  def realized_from_invoices
    range = period_range
    return 0 unless range && cost_center_id

    cost_center.invoices.where(issued_at: range).sum(:value)
  end

  # Recalcula e persiste o realizado sem disparar validações/callbacks.
  def sync_realized!
    update_column(:realized_total, realized_from_invoices)
  end

  def difference
    realized_total - forecasted_total
  end

  private

  def set_realized_from_invoices
    self.realized_total = realized_from_invoices
  end
end
