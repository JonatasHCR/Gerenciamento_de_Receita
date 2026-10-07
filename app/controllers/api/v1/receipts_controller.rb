module Api
  module V1
    # Recebimentos das NFs para o Controle Financeiro.
    class ReceiptsController < BaseController
      # GET /api/v1/receipts?updated_since=&limit=&offset=
      def index
        render_incremental(:receipts, Receipt.all) do |r|
          {
            id: r.id,
            invoice_id: r.invoice_id,
            payment_date: r.payment_date,
            value: r.value,
            updated_at: r.updated_at.iso8601(6)
          }
        end
      end
    end
  end
end
