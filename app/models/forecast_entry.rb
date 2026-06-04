class ForecastEntry < ApplicationRecord
  has_paper_trail

  belongs_to :cost_center

  validates :month_year, presence: true, uniqueness: { scope: :cost_center_id }
  validates :forecasted_total, numericality: { greater_than_or_equal_to: 0 }
  validates :realized_total, numericality: { greater_than_or_equal_to: 0 }

  scope :for_month, ->(month_year) { where(month_year: month_year) }
  scope :ordered, -> { joins(:cost_center).order("cost_centers.cr_code") }

  def difference
    realized_total - forecasted_total
  end
end
