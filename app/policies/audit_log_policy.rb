class AuditLogPolicy < ApplicationPolicy
  def index? = admin?
  def show?  = admin?
end
