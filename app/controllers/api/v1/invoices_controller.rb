module Api
  module V1
    # Notas fiscais para o Controle Financeiro.
    class InvoicesController < BaseController
      # GET /api/v1/invoices?updated_since=&limit=&offset=
      def index
        render_incremental(:invoices, Invoice.includes(:cost_center)) do |nf|
          {
            id: nf.id,
            cost_center_id: nf.cost_center_id,
            cr_code: nf.cost_center&.cr_code,
            number: nf.number,
            client_name: nf.client_name,
            issued_at: nf.issued_at,
            kind: nf.kind,
            value: nf.value,
            observations: nf.observations,
            updated_at: nf.updated_at.iso8601(6)
          }
        end
      end
    end
  end
end
