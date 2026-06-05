class ReportPolicy < ApplicationPolicy
  def monthly? = admin? || financeiro?
end
