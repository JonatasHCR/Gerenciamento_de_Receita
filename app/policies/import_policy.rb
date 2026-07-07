class ImportPolicy < ApplicationPolicy
  def new?    = admin? || financeiro?
  def create? = admin? || financeiro?
  def users?  = admin?
end
