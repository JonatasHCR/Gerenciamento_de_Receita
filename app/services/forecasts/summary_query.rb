module Forecasts
  class SummaryQuery
    def initialize(month_year:, scope: ForecastEntry)
      @month_year = month_year
      @scope      = scope
    end

    def call
      entries = @scope.for_month(@month_year)
                      .includes(cost_center: :client)
                      .ordered
                      .to_a

      preload_realized(entries)
      entries.group_by { |e| e.cost_center.client }
    end

    private

    # Calcula o realizado de todos os CCs do mês numa única query e injeta em
    # cada entry (evita N+1 ao somar realized_total na listagem/dashboard).
    def preload_realized(entries)
      range = entries.first&.period_range
      return unless range

      totals = Invoice.where(cost_center_id: entries.map(&:cost_center_id).uniq, issued_at: range)
                      .group(:cost_center_id).sum(:value)
      entries.each { |e| e.realized_total = (totals[e.cost_center_id] || 0) }
    end
  end
end
