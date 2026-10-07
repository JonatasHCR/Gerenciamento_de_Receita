module Api
  module V1
    # Impressão digital de cada tabela, para o Controle Financeiro saber se a cópia dela
    # divergiu e precisa reconciliar.
    class StatusController < BaseController
      # GET /api/v1/status
      def show
        render json: {
          clients: resumo(Client),
          cost_centers: resumo(CostCenter, :value),
          invoices: resumo(Invoice, :value),
          receipts: resumo(Receipt, :value),
          adjustments: resumo(Adjustment),
          forecast_entries: resumo(ForecastEntry, :forecasted_total)
        }
      end

      private

      def resumo(modelo, coluna_soma = nil)
        {
          count: modelo.count,
          max_updated_at: modelo.maximum(:updated_at)&.iso8601(6),
          sum: coluna_soma && modelo.sum(coluna_soma)
        }.compact
      end
    end
  end
end
