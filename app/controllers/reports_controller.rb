class ReportsController < ApplicationController
  def index
    authorize :report, :index?
  end

  def monthly
    authorize :report, :monthly?

    period_start, period_end, label, ranged = resolve_period

    report_data = Reports::MonthlyReportQuery.new(
      period_start: period_start,
      period_end:   period_end,
      scope:        policy_scope(CostCenter)
    ).call

    pdf = Reports::MonthlyReportPdf.new(
      report_data:  report_data,
      period_label: label,
      ranged:       ranged,
      generated_by: current_user.name
    ).render

    send_data pdf,
              filename: "relatorio_#{period_start.strftime('%Y%m%d')}_#{period_end.strftime('%Y%m%d')}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  # Modo período (start + end válidos) ou mês (default = mês atual).
  def resolve_period
    start_date = parse_date(params[:start])
    end_date   = parse_date(params[:end])

    if start_date && end_date && end_date >= start_date
      [start_date, end_date,
       "#{I18n.l(start_date)} a #{I18n.l(end_date)}", true]
    else
      month = parse_month(params[:month])
      [month.beginning_of_month, month.end_of_month, pt_month_year(month), false]
    end
  end
end
