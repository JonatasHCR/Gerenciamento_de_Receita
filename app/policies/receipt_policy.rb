class ReceiptPolicy < ApplicationPolicy
  def index?   = admin? || financeiro?
  def show?    = admin? || financeiro?
  def create?  = admin? || financeiro?
  def update?  = admin? || financeiro?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin? || user.financeiro?
      scope.none
    end
  end
end
