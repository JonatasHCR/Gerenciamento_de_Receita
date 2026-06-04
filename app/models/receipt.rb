class Receipt < ApplicationRecord
  has_paper_trail

  belongs_to :invoice

  validates :payment_date, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }
  validate :value_does_not_exceed_invoice_balance

  scope :for_month, ->(date) { where(payment_date: date.beginning_of_month..date.end_of_month) }
  scope :ordered, -> { order(payment_date: :desc) }

  delegate :cost_center, to: :invoice

  private

  def value_does_not_exceed_invoice_balance
    return unless invoice && value

    existing_receipts_sum = invoice.receipts.where.not(id: id).sum(:value)
    if existing_receipts_sum + value > invoice.value
      errors.add(:value, :exceeds_invoice_balance,
        message: "não pode exceder o saldo da nota fiscal (R$ #{invoice.balance})")
    end
  end
end
