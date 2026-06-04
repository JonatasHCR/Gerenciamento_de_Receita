class ClientPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = admin? || financeiro?
  def update? = admin? || financeiro?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end
end
