class ReportsController < ApplicationController
  def monthly
    authorize :report, :monthly?

    month      = parse_month(params[:month])
    month_year = pt_month_year(month)

    report_data = Reports::MonthlyReportQuery.new(
      month:      month,
      month_year: month_year,
      scope:      policy_scope(CostCenter)
    ).call

    pdf = Reports::MonthlyReportPdf.new(
      report_data:  report_data,
      month_label:  month_year,
      generated_by: current_user.name
    ).render

    send_data pdf,
              filename: "relatorio_#{month.strftime('%Y_%m')}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end
end
