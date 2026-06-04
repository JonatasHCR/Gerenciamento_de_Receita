class DashboardController < ApplicationController
  def index
    skip_authorization
    @month = params[:month] ? Date.parse("#{params[:month]}-01") : Date.current.beginning_of_month

    if current_user.admin_or_financeiro?
      @total_invoiced   = Invoice.for_month(@month).sum(:value)
      @total_received   = Receipt.for_month(@month).sum(:value)
      @open_invoices_count  = Invoice.with_open_balance.count
      @open_balance         = Invoice.with_open_balance
                                     .sum("invoices.value - COALESCE(r.received, 0)")

      @invoices_by_month = Invoice
        .where(issued_at: 6.months.ago..Date.current)
        .group_by_month(:issued_at, format: "%b/%Y")
        .sum(:value)

      @receipts_by_month = Receipt
        .where(payment_date: 6.months.ago..Date.current)
        .group_by_month(:payment_date, format: "%b/%Y")
        .sum(:value)
    end

    @forecast_summary = Forecasts::SummaryQuery.new(
      month_year: pt_month_year(@month),
      scope: policy_scope(ForecastEntry)
    ).call
  end
end
