class Adjustment < ApplicationRecord
  has_paper_trail

  belongs_to :cost_center

  # valor: mexe no valor do contrato; prazo: mexe na data final.
  enum :kind, { valor: 0, prazo: 1 }

  attr_accessor :amount

  validates :kind, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_blank: true
  validates :new_value, presence: true, numericality: { greater_than: 0 }, if: :valor?
  validates :new_date,  presence: true, if: :prazo?
  validate :new_date_not_before_start, if: :prazo?

  before_validation :capture_previous, on: :create
  before_validation :apply_amount, on: :create
  after_create :apply_to_cost_center

  scope :recent, -> { order(created_at: :desc) }

  def value_delta
    return unless valor?
    new_value.to_d - previous_value.to_d
  end

  private

  def apply_amount
    return unless valor? && amount.present?
    self.new_value = previous_value.to_d + amount.to_d
  end

  def new_date_not_before_start
    return if new_date.blank? || cost_center&.start_date.blank?
    if new_date < cost_center.start_date
      errors.add(:new_date, "não pode ser anterior à data de início do contrato")
    end
  end

  def capture_previous
    if valor?
      self.previous_value = cost_center&.value
    elsif prazo?
      self.previous_date = cost_center&.end_date
    end
  end

  def apply_to_cost_center
    if valor?
      cost_center.update_column(:value, new_value)
    elsif prazo?
      cost_center.update_column(:end_date, new_date)
    end
  end
end
