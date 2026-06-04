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

      chart_start = Date.new(@month.year, 1, 1)
      chart_end   = @month.end_of_month

      @chart_months = @month.month
      @chart_year   = @month.year

      chart_range = chart_start..chart_end

      @invoices_by_month = Invoice
        .where(issued_at: chart_range)
        .group_by_month(:issued_at, format: "%m/%Y", range: chart_range)
        .sum(:value)
        .transform_keys { |k| pt_month_label(k) }

      @receipts_by_month = Receipt
        .where(payment_date: chart_range)
        .group_by_month(:payment_date, format: "%m/%Y", range: chart_range)
        .sum(:value)
        .transform_keys { |k| pt_month_label(k) }
    end

    @forecast_summary = Forecasts::SummaryQuery.new(
      month_year: pt_month_year(@month),
      scope: policy_scope(ForecastEntry)
    ).call
  end
end
