class ReportsController < ApplicationController
  def index
    authorize :report, :index?
    scope = policy_scope(CostCenter)
    @scope_cost_centers = scope.includes(:client).ordered
    @scope_clients      = Reports::ScopeFilter.client_options(scope)
    @scope_coordinators = Reports::ScopeFilter.coordinator_options(scope)
    # Coordenadores de cada cliente — o filtro em cascata usa isso para estreitar
    # a lista de clientes conforme os coordenadores marcados.
    @client_coordinators = @scope_cost_centers.group_by(&:client_id)
                                              .transform_values { |ccs| ccs.flat_map(&:coordinator_list).uniq }
  end

  def monthly
    authorize :report, :monthly?

    period_start, period_end, label, ranged = resolve_period
    filter = build_filter

    report_data = Reports::MonthlyReportQuery.new(
      period_start: period_start,
      period_end:   period_end,
      scope:        filter.cost_centers,
      levels:       filter.levels(row_is_cost_center: true)
    ).call

    pdf = Reports::MonthlyReportPdf.new(
      report_data:  report_data,
      period_label: label,
      ranged:       ranged,
      filter_label: filter.label,
      generated_by: current_user.name
    ).render

    send_data pdf,
              filename: "relatorio_#{period_start.strftime('%Y%m%d')}_#{period_end.strftime('%Y%m%d')}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  # Relatório de Movimentação: faturamento (data de emissão) e/ou recebimento
  # (data de baixa), destacando e totalizando o que está em aberto.
  def movement
    authorize :report, :movement?

    filter = build_filter
    period_start = parse_date(params[:start])
    period_end   = parse_date(params[:end])
    period_end, period_start = period_start, period_end if period_start && period_end && period_end < period_start

    data = Reports::MovementReportQuery.new(
      filter:       filter,
      tipo:         params[:tipo],
      period_start: period_start,
      period_end:   period_end,
      only_open:    params[:only_open]
    ).call

    stamp = Date.current.strftime("%Y%m%d")
    labels = { filter_label: filter.label, period_label: period_label(period_start, period_end) }

    if params[:output] == "xlsx"
      send_data Reports::MovementXlsx.new(data, **labels).call,
                filename: "movimentacao_#{stamp}.xlsx",
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                disposition: "attachment"
    else
      send_data Reports::MovementPdf.new(report_data: data, generated_by: current_user.name, **labels).render,
                filename: "movimentacao_#{stamp}.pdf",
                type: "application/pdf",
                disposition: "attachment"
    end
  end

  private

  def build_filter
    Reports::ScopeFilter.from_params(params, scope: policy_scope(CostCenter))
  end

  def period_label(period_start, period_end)
    return nil if period_start.blank? && period_end.blank?
    return "Período: a partir de #{I18n.l(period_start)}" if period_end.blank?
    return "Período: até #{I18n.l(period_end)}"           if period_start.blank?
    "Período: #{I18n.l(period_start)} a #{I18n.l(period_end)}"
  end

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
