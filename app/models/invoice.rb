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

  RECEIVED_JOIN = "LEFT JOIN (SELECT invoice_id, SUM(value) AS received, MAX(payment_date) AS last_payment " \
                  "FROM receipts GROUP BY invoice_id) r ON r.invoice_id = invoices.id".freeze

  scope :for_month, ->(date) { where(issued_at: date.beginning_of_month..date.end_of_month) }
  # O Rails deduplica strings de joins idênticas, então compor
  # `with_received.with_open_balance` não gera LEFT JOIN duplicado.
  scope :joined_received, -> { joins(RECEIVED_JOIN) }
  scope :with_open_balance, -> { joined_received.where("invoices.value > COALESCE(r.received, 0)") }
  # Expõe o recebido pré-calculado em `preloaded_received` (evita N+1 no #balance)
  # e a data da ÚLTIMA baixa em `preloaded_last_payment` (nil quando não houve).
  #
  # `cutoff` faz o SNAPSHOT na data: baixa posterior ao corte NÃO conta — uma NF
  # paga dia 15 aparece como em aberto num relatório que vai até o dia 14.
  scope :with_received, ->(cutoff = nil) {
    joins(received_join(cutoff))
      .select("invoices.*, COALESCE(r.received, 0) AS preloaded_received, r.last_payment AS preloaded_last_payment")
  }

  scope :ordered, -> { order(issued_at: :desc) }

  def self.received_join(cutoff = nil)
    return RECEIVED_JOIN if cutoff.blank?

    sanitize_sql_array([
      "LEFT JOIN (SELECT invoice_id, SUM(value) AS received, MAX(payment_date) AS last_payment " \
      "FROM receipts WHERE payment_date <= ? GROUP BY invoice_id) r ON r.invoice_id = invoices.id",
      cutoff
    ])
  end

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
