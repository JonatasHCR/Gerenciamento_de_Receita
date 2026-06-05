class Adjustment < ApplicationRecord
  has_paper_trail

  belongs_to :cost_center

  # valor: mexe no valor do contrato; prazo: mexe na data final.
  enum :kind, { valor: 0, prazo: 1 }

  validates :kind, presence: true
  validates :new_value, presence: true, numericality: { greater_than: 0 }, if: :valor?
  validates :new_date,  presence: true, if: :prazo?

  before_validation :capture_previous, on: :create
  after_create :apply_to_cost_center

  scope :recent, -> { order(created_at: :desc) }

  private

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
