class UserPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin? || record == user
  def create?  = admin?
  def update?  = admin? || record == user
  def edit?    = update?
  def destroy? = admin? && record != user

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?
      scope.where(id: user.id)
    end
  end
end
