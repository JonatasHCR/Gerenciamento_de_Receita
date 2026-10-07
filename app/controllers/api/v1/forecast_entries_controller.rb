module Api
  module V1
    # Previsão mensal de faturamento para o Controle Financeiro.
    class ForecastEntriesController < BaseController
      # GET /api/v1/forecast_entries?updated_since=&limit=&offset=
      def index
        render_incremental(:forecast_entries, ForecastEntry.all) do |f|
          {
            id: f.id,
            cost_center_id: f.cost_center_id,
            month_year: f.month_year,
            forecasted_total: f.forecasted_total,
            updated_at: f.updated_at.iso8601(6)
          }
        end
      end
    end
  end
end
