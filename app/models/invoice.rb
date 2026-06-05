class Invoice < ApplicationRecord
  has_paper_trail

  belongs_to :cost_center
  has_many :receipts, dependent: :destroy

  # principal = faturamento do contrato; reajuste = NF de reajuste (não entra no saldo principal)
  enum :kind, { principal: 0, reajuste: 1 }

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
end
