class InvoicePolicy < ApplicationPolicy
  def index?   = admin? || financeiro?
  def show?    = admin? || financeiro?
  def create?  = admin? || financeiro?
  def update?
    return false if financeiro? && record.paid?
    admin? || financeiro?
  end
  def destroy? = admin? || financeiro?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin? || user.financeiro?
      scope.none
    end
  end
end
