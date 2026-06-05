class User < ApplicationRecord
  devise :database_authenticatable, :argon2,
         :validatable, :lockable, :timeoutable

  has_paper_trail

  enum :role, { coordenador: 0, gestor: 1, financeiro: 2, admin: 3 }

  has_many :user_cost_centers, dependent: :destroy
  has_many :cost_centers, through: :user_cost_centers

  validates :name, presence: true
  validates :role, presence: true

  def admin_or_financeiro?
    admin? || financeiro?
  end
end
