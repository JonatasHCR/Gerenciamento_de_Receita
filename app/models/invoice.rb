class Invoice < ApplicationRecord
  has_paper_trail

  belongs_to :cost_center
  has_many :receipts, dependent: :destroy

  validates :number, presence: true, uniqueness: { scope: :cost_center_id }
  validates :client_name, presence: true
  validates :issued_at, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }

  scope :for_month, ->(date) { where(issued_at: date.beginning_of_month..date.end_of_month) }
  scope :with_open_balance, -> {
    joins("LEFT JOIN (SELECT invoice_id, SUM(value) AS received FROM receipts GROUP BY invoice_id) r ON r.invoice_id = invoices.id")
      .where("invoices.value > COALESCE(r.received, 0)")
  }
  scope :ordered, -> { order(issued_at: :desc) }

  # Mantém ForecastEntry.realized_total em sincronia com o faturamento.
  after_commit :sync_forecast_realized, on: [:create, :update, :destroy]

  def received_amount
    # Usa valor pré-calculado via JOIN subquery quando disponível (index/list queries),
    # evitando N+1. Cai no SQL SUM apenas em queries pontuais (show, validações).
    if has_attribute?(:preloaded_received)
      self[:preloaded_received] || 0
    elsif receipts.loaded?
      receipts.sum(&:value)
    else
      receipts.sum(:value)
    end
  end

  def balance
    value - received_amount
  end

  def paid?
    balance <= 0
  end

  def partially_paid?
    received_amount > 0 && !paid?
  end

  def payment_status
    if paid?
      :paid
    elsif partially_paid?
      :partial
    else
      :unpaid
    end
  end

  private

  # Recalcula o realizado da previsão do mês deste CC. Em alterações de
  # data/CC, sincroniza também a previsão do período/CC anterior.
  def sync_forecast_realized
    pairs = [[cost_center_id, issued_at]]

    if saved_change_to_issued_at? || saved_change_to_cost_center_id?
      prev_cc   = saved_change_to_cost_center_id? ? saved_change_to_cost_center_id.first : cost_center_id
      prev_date = saved_change_to_issued_at?      ? saved_change_to_issued_at.first      : issued_at
      pairs << [prev_cc, prev_date]
    end

    pairs.uniq.each do |cc_id, date|
      next unless cc_id && date

      ForecastEntry
        .find_by(cost_center_id: cc_id, month_year: ForecastEntry.month_year_for(date))
        &.sync_realized!
    end
  end
end
