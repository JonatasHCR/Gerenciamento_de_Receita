class InvoicePolicy < ApplicationPolicy
  def index?   = admin? || financeiro?
  def show?    = admin? || financeiro?
  def create?  = admin? || financeiro?
  # Permite editar a NF mesmo quitada (admin e financeiro).
  def update? = admin? || financeiro?
  def destroy? = admin? || financeiro?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin? || user.financeiro?
      scope.none
    end
  end
end
