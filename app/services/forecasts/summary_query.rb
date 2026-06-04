module Forecasts
  class SummaryQuery
    def initialize(month_year:, scope: ForecastEntry)
      @month_year = month_year
      @scope      = scope
    end

    def call
      @scope
        .for_month(@month_year)
        .includes(cost_center: :client)
        .ordered
        .group_by { |e| e.cost_center.client }
    end
  end
end
