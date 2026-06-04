module Reports
  # Agrega os dados do relatório mensal por cliente → centros de custo.
  #
  # Para cada centro de custo retorna:
  #   previsto   → ForecastEntry.forecasted_total do mês
  #   inv_cur    → faturamento emitido no mês
  #   inv_pre    → faturamento emitido em meses anteriores
  #   rec_cur    → recebimentos no mês
  #   open       → saldo em aberto até o fim do mês (faturado − recebido)
  #
  # Estrutura de retorno:
  #   [
  #     { client:, cost_centers: [ {cc:, previsto:, inv_cur:, inv_pre:, rec_cur:, open:}, ... ],
  #       totals: {...} },
  #     ...
  #   ]
  class MonthlyReportQuery
    def initialize(month:, month_year:, scope: CostCenter.all)
      @month      = month.beginning_of_month
      @month_end  = month.end_of_month
      @month_year = month_year
      @scope      = scope
    end

    def call
      data = Hash.new { |h, k| h[k] = {} }

      ForecastEntry.where(month_year: @month_year)
                   .group(:cost_center_id).sum(:forecasted_total)
                   .each { |id, v| data[id][:previsto] = v }

      Invoice.where(issued_at: @month..@month_end)
             .group(:cost_center_id).sum(:value)
             .each { |id, v| data[id][:inv_cur] = v }

      Invoice.where("issued_at < ?", @month)
             .group(:cost_center_id).sum(:value)
             .each { |id, v| data[id][:inv_pre] = v }

      Receipt.joins(:invoice).where(payment_date: @month..@month_end)
             .group("invoices.cost_center_id").sum("receipts.value")
             .each { |id, v| data[id][:rec_cur] = v }

      # Saldo em aberto até o fim do mês: faturado (<= fim do mês) − recebido (<= fim do mês)
      Invoice.where("issued_at <= ?", @month_end)
             .group(:cost_center_id).sum(:value)
             .each { |id, v| data[id][:inv_until] = v }

      Receipt.joins(:invoice).where("receipts.payment_date <= ?", @month_end)
             .group("invoices.cost_center_id").sum("receipts.value")
             .each { |id, v| data[id][:rec_until] = v }

      grouped = Hash.new { |h, k| h[k] = [] }

      @scope.includes(:client).joins(:client)
            .where(id: data.keys)
            .order("clients.name", "cost_centers.cr_code")
            .each do |cc|
        d = data[cc.id]
        grouped[cc.client] << {
          cc:       cc,
          previsto: d[:previsto] || 0,
          inv_cur:  d[:inv_cur]  || 0,
          inv_pre:  d[:inv_pre]  || 0,
          rec_cur:  d[:rec_cur]  || 0,
          open:     (d[:inv_until] || 0) - (d[:rec_until] || 0)
        }
      end

      grouped.map do |client, rows|
        {
          client:       client,
          cost_centers: rows,
          totals:       sum_rows(rows)
        }
      end
    end

    private

    def sum_rows(rows)
      {
        previsto: rows.sum { |r| r[:previsto] },
        inv_cur:  rows.sum { |r| r[:inv_cur] },
        inv_pre:  rows.sum { |r| r[:inv_pre] },
        rec_cur:  rows.sum { |r| r[:rec_cur] },
        open:     rows.sum { |r| r[:open] }
      }
    end
  end
end
