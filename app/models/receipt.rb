class Receipt < ApplicationRecord
  has_paper_trail

  belongs_to :invoice

  validates :payment_date, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }
  validate :value_does_not_exceed_invoice_balance
  validate :payment_date_not_before_invoice_issued_at

  scope :for_month, ->(date) { where(payment_date: date.beginning_of_month..date.end_of_month) }
  scope :ordered, -> { order(payment_date: :desc) }

  delegate :cost_center, to: :invoice

  private

  def payment_date_not_before_invoice_issued_at
    return unless invoice&.issued_at && payment_date
    if payment_date < invoice.issued_at
      errors.add(:payment_date, "não pode ser anterior à data de emissão da nota fiscal (#{invoice.issued_at.strftime('%d/%m/%Y')})")
    end
  end

  def value_does_not_exceed_invoice_balance
    return unless invoice && value

    existing_receipts_sum = invoice.receipts.where.not(id: id).sum(:value)
    available = invoice.value - existing_receipts_sum
    return if value <= available

    formatted = ActiveSupport::NumberHelper.number_to_currency(
      available, unit: "R$ ", separator: ",", delimiter: ".", precision: 2
    )
    errors.add(:value, message: "não pode exceder o saldo disponível da nota (#{formatted})")
  end
end
