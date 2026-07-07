module Reports
  # Agrega as NFs em ABERTO (saldo > 0) por cliente → centro de custo, para a
  # "Relação das Faturas em Aberto". VALOR = saldo em aberto (valor − recebido).
  #
  # Retorno:
  #   [ { client:, cost_centers: [ { cc:, invoices: [Invoice,...], subtotal: } ], total: }, ... ]
  class OpenInvoicesReportQuery
    def initialize(client_ids: nil)
      @client_ids = Array(client_ids).reject(&:blank?).presence
    end

    def call
      rel = Invoice.with_open_balance
                   .joins(cost_center: :client)
                   .select("invoices.*, COALESCE(r.received, 0) AS preloaded_received")
                   .includes(cost_center: :client)
                   .order("clients.name", "cost_centers.cr_code", "invoices.issued_at")
      rel = rel.where(cost_centers: { client_id: @client_ids }) if @client_ids

      rel.group_by { |inv| inv.cost_center.client }
         .sort_by { |client, _| client.name.to_s }
         .map { |client, invoices| build_client(client, invoices) }
    end

    private

    def build_client(client, invoices)
      cost_centers = invoices.group_by(&:cost_center)
                             .sort_by { |cc, _| cc.cr_code.to_s }
                             .map do |cc, invs|
        { cc: cc, invoices: invs, subtotal: invs.sum(&:balance) }
      end

      { client: client, cost_centers: cost_centers, total: invoices.sum(&:balance) }
    end
  end
end
