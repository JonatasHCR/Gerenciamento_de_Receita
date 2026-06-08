module Reports
  # Agrega os dados do relatório mensal por cliente → centros de custo.
  #
  # Para cada centro de custo retorna:
  #   previsto   → ForecastEntry.forecasted_total do mês
  #   inv_cur    → faturamento emitido no mês
  #   inv_pre    → faturamento emitido em meses anteriores
  #   open_pre   → em aberto das NFs anteriores (inv_pre − recebido pago até o mês anterior)
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
      q_start = connection.quote(@month)
      q_end   = connection.quote(@month_end)

      ForecastEntry.where(month_year: @month_year)
                   .group(:cost_center_id).sum(:forecasted_total)
                   .each { |id, v| data[id][:previsto] = v }

      # Faturamento (<= fim do mês) por CC: mês atual × meses anteriores numa query.
      Invoice.where("issued_at <= #{q_end}")
             .group(:cost_center_id)
             .pluck(
               :cost_center_id,
               Arel.sql("COALESCE(SUM(CASE WHEN issued_at >= #{q_start} THEN value ELSE 0 END), 0)"),
               Arel.sql("COALESCE(SUM(CASE WHEN issued_at <  #{q_start} THEN value ELSE 0 END), 0)")
             )
             .each { |id, cur, pre| data[id].merge!(inv_cur: cur, inv_pre: pre) }

      # Recebimentos (<= fim do mês) por CC: no mês, total, e sobre NFs anteriores.
      # rec_on_pre conta só pagamentos ATÉ o mês anterior (payment_date < início do mês),
      # ignorando pagamentos no mês selecionado/futuro.
      Receipt.joins(:invoice)
             .where("receipts.payment_date <= #{q_end}")
             .group("invoices.cost_center_id")
             .pluck(
               Arel.sql("invoices.cost_center_id"),
               Arel.sql("COALESCE(SUM(CASE WHEN receipts.payment_date >= #{q_start} THEN receipts.value ELSE 0 END), 0)"),
               Arel.sql("COALESCE(SUM(receipts.value), 0)"),
               Arel.sql("COALESCE(SUM(CASE WHEN invoices.issued_at < #{q_start} AND receipts.payment_date < #{q_start} THEN receipts.value ELSE 0 END), 0)")
             )
             .each { |id, cur, until_end, on_pre| data[id].merge!(rec_cur: cur, rec_until: until_end, rec_on_pre: on_pre) }

      grouped = Hash.new { |h, k| h[k] = [] }

      @scope.includes(:client).joins(:client)
            .where(id: data.keys)
            .order("clients.name", "cost_centers.cr_code")
            .each do |cc|
        d        = data[cc.id]
        inv_cur  = d[:inv_cur] || 0
        inv_pre  = d[:inv_pre] || 0
        grouped[cc.client] << {
          cc:       cc,
          previsto: d[:previsto] || 0,
          inv_cur:  inv_cur,
          inv_pre:  inv_pre,
          open_pre: inv_pre - (d[:rec_on_pre] || 0),
          rec_cur:  d[:rec_cur] || 0,
          open:     (inv_cur + inv_pre) - (d[:rec_until] || 0)
        }
      end

      # Omite CCs com TODOS os valores exibidos zerados; e clientes cujos CCs
      # ficaram todos zerados. Se algum CC tiver valor, o cliente aparece.
      grouped.filter_map do |client, rows|
        visible = rows.reject { |r| display_all_zero?(r) }
        next if visible.empty?

        {
          client:       client,
          cost_centers: visible,
          totals:       sum_rows(visible)
        }
      end
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    # Colunas monetárias exibidas no relatório (PDF). "Tudo zerado" = todas elas 0.
    DISPLAY_KEYS = %i[previsto inv_cur open_pre rec_cur open].freeze

    def display_all_zero?(row)
      DISPLAY_KEYS.all? { |k| row[k].to_d.zero? }
    end

    def sum_rows(rows)
      {
        previsto: rows.sum { |r| r[:previsto] },
        inv_cur:  rows.sum { |r| r[:inv_cur] },
        inv_pre:  rows.sum { |r| r[:inv_pre] },
        open_pre: rows.sum { |r| r[:open_pre] },
        rec_cur:  rows.sum { |r| r[:rec_cur] },
        open:     rows.sum { |r| r[:open] }
      }
    end
  end
end
