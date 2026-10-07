module Api
  module V1
    # Clientes para o Controle Financeiro.
    class ClientsController < BaseController
      # GET /api/v1/clients?updated_since=&limit=&offset=
      def index
        render_incremental(:clients, Client.all) do |c|
          { id: c.id, name: c.name, full_name: c.full_name, updated_at: c.updated_at.iso8601(6) }
        end
      end
    end
  end
end
