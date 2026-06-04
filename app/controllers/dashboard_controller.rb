class DashboardController < ApplicationController
  def index
    skip_authorization
    @month = params[:month] ? Date.parse("#{params[:month]}-01") : Date.current.beginning_of_month

    if current_user.admin_or_financeiro?
      @total_invoiced   = Invoice.for_month(@month).sum(:value)
      @total_received   = Receipt.for_month(@month).sum(:value)
      open_current_month  = Invoice.with_open_balance.for_month(@month)
      open_prev_months    = Invoice.with_open_balance.where("issued_at < ?", @month)

      @open_balance                     = Invoice.with_open_balance.sum("invoices.value - COALESCE(r.received, 0)")
      @open_invoices_count              = Invoice.with_open_balance.count
      @open_balance_current_month       = open_current_month.sum("invoices.value - COALESCE(r.received, 0)")
      @open_invoices_current_month_count = open_current_month.count
      @open_balance_previous_months     = open_prev_months.sum("invoices.value - COALESCE(r.received, 0)")
      @open_invoices_previous_months_count = open_prev_months.count

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

      # ── Faturado × Recebido por cliente/CC ─────────────────────────────────
      bdata = Hash.new { |h, k| h[k] = {} }

      Invoice.for_month(@month).group(:cost_center_id).sum(:value)
             .each { |id, v| bdata[id][:inv_cur] = v }
      Receipt.joins(:invoice).for_month(@month)
             .group("invoices.cost_center_id").sum("receipts.value")
             .each { |id, v| bdata[id][:rec_cur] = v }

      Invoice.where("issued_at < ?", @month).group(:cost_center_id).sum(:value)
             .each { |id, v| bdata[id][:inv_pre] = v }
      Receipt.joins(:invoice).where("receipts.payment_date < ?", @month)
             .group("invoices.cost_center_id").sum("receipts.value")
             .each { |id, v| bdata[id][:rec_pre] = v }

      @billing_by_client = {}
      CostCenter.includes(:client)
                .where(id: bdata.keys)
                .joins(:client)
                .order("clients.name", "cost_centers.cr_code")
                .each do |cc|
        d       = bdata[cc.id]
        inv_cur = d[:inv_cur] || 0
        inv_pre = d[:inv_pre] || 0
        rec_cur = d[:rec_cur] || 0
        rec_pre = d[:rec_pre] || 0
        @billing_by_client[cc.client] ||= []
        @billing_by_client[cc.client] << {
          cc:        cc,
          inv_cur:   inv_cur,
          rec_cur:   rec_cur,
          inv_pre:   inv_pre,
          rec_pre:   rec_pre,
          inv_total: inv_cur + inv_pre,
          rec_total: rec_cur + rec_pre,
          open:      inv_cur + inv_pre - rec_cur - rec_pre
        }
      end
    end

    @forecast_summary = Forecasts::SummaryQuery.new(
      month_year: pt_month_year(@month),
      scope: policy_scope(ForecastEntry)
    ).call
  end
end
