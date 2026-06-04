class Client < ApplicationRecord
  has_paper_trail

  has_many :cost_centers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
