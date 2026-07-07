class ReportPolicy < ApplicationPolicy
  def index?         = true
  def monthly?       = admin? || financeiro?
  def open_invoices? = admin? || financeiro?
end
