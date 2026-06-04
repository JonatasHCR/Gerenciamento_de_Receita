class UserCostCenter < ApplicationRecord
  belongs_to :user
  belongs_to :cost_center

  validates :user_id, uniqueness: { scope: :cost_center_id }
end
