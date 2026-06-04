class ImportPolicy < ApplicationPolicy
  def new?    = admin? || financeiro?
  def create? = admin? || financeiro?
end
