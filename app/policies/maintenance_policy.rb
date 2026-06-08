class MaintenancePolicy < ApplicationPolicy
  def index?    = admin?
  def backup?   = admin?
  def cleanup?  = admin?
  def restore?  = admin?
  def download? = admin?
end
