class ReportPolicy < ApplicationPolicy
  def index?   = true
  def monthly? = admin? || financeiro?
end
