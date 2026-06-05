class CostCenter < ApplicationRecord
  has_paper_trail

  belongs_to :client
  has_many :user_cost_centers, dependent: :destroy
  has_many :users, through: :user_cost_centers
  has_many :invoices, dependent: :restrict_with_error
  has_many :forecast_entries, dependent: :destroy
  has_many :adjustments, dependent: :destroy

  validates :cr_code, presence: true, uniqueness: true
  validates :description, presence: true
  validates :participation, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validate :end_date_not_before_start_date

  scope :ordered, -> { order(:cr_code) }

  # Um CC pode ter mais de um coordenador/gestor. Armazenado no campo string
  # `coordinator` com os nomes separados por " / " (mesmo formato da planilha).
  COORDINATOR_SEP = " / ".freeze

  def coordinator_list
    coordinator.to_s.split("/").map(&:strip).reject(&:blank?)
  end

  def coordinator_list=(values)
    self.coordinator = Array(values).map { |v| v.to_s.strip }.reject(&:blank?).join(COORDINATOR_SEP)
  end

  # Participação informada/exibida em percentual (0 a 100), armazenada como
  # decimal (0 a 1,0) no banco.
  def participation_percent
    return nil if participation.nil?
    pct = participation * 100
    pct == pct.to_i ? pct.to_i : pct
  end

  def participation_percent=(value)
    self.participation = value.present? ? (value.to_d / 100) : nil
  end

  # Total faturado considerando apenas NFs PRINCIPAIS (reajustes não entram).
  def principal_invoiced
    invoices.principal.sum(:value)
  end

  # Saldo = valor do contrato − faturado principal.
  def saldo
    (value || 0) - principal_invoiced
  end

  # % a executar = saldo em relação ao valor do contrato (0 a 100, 2 casas).
  def percent_to_execute
    return 0 if value.to_f.zero?
    (saldo / value * 100).round(2)
  end
end
