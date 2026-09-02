class ReportPolicy < ApplicationPolicy
  def index?     = true
  def monthly?   = admin? || financeiro?
  def movement?  = admin? || financeiro?
end
