class CostCenter < ApplicationRecord
  has_paper_trail

  belongs_to :client
  has_many :user_cost_centers, dependent: :destroy
  has_many :users, through: :user_cost_centers
  has_many :invoices, dependent: :restrict_with_error
  has_many :forecast_entries, dependent: :destroy

  validates :cr_code, presence: true, uniqueness: true
  validates :description, presence: true
  validates :participation, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }

  scope :ordered, -> { order(:cr_code) }

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
end
