module Reports
  # Agrega os dados do relatório mensal por centro de custo e monta a árvore de
  # agrupamento (cliente, coordenador → cliente, ou lista plana) via GroupTree.
  #
  # Para cada centro de custo:
  #   previsto   → ForecastEntry.forecasted_total do período
  #   inv_cur    → faturamento emitido no período
  #   inv_pre    → faturamento emitido antes do período
  #   open_pre   → em aberto das NFs anteriores (inv_pre − recebido pago antes do período)
  #   rec_cur    → recebimentos no período
  #   open       → saldo em aberto até o fim do período (faturado − recebido)
  #
  # #rows  → linhas planas [{ cc:, client:, previsto:, ... }, ...]
  # #call  → { levels:, groups: [...], totals: {...} }  (ver Reports::GroupTree)
  class MonthlyReportQuery
    # Colunas monetárias exibidas no relatório (PDF). "Tudo zerado" = todas elas 0.
    DISPLAY_KEYS = %i[previsto inv_cur open_pre rec_cur open].freeze
    SUM_KEYS     = (DISPLAY_KEYS + %i[inv_pre]).freeze

    def initialize(period_start:, period_end:, scope: CostCenter.all, levels: [:cliente])
      @period_start = period_start
      @period_end   = period_end
      @scope        = scope
      @levels       = Array(levels)
    end

    def call
      GroupTree.build(rows, levels: @levels, sum_keys: SUM_KEYS)
    end

    def rows
      @rows ||= build_rows
    end

    private

    def build_rows
      data    = Hash.new { |h, k| h[k] = {} }
      q_start = connection.quote(@period_start)
      q_end   = connection.quote(@period_end)
      cc_ids  = @scope.reselect(:id)

      ForecastEntry.where(cost_center_id: cc_ids, month_year: month_year_labels)
                   .group(:cost_center_id).sum(:forecasted_total)
                   .each { |id, v| data[id][:previsto] = v }

      # Faturamento (<= fim do período) por CC: no período × antes dele, numa query.
      Invoice.where(cost_center_id: cc_ids)
             .where("issued_at <= #{q_end}")
             .group(:cost_center_id)
             .pluck(
               :cost_center_id,
               Arel.sql("COALESCE(SUM(CASE WHEN issued_at >= #{q_start} THEN value ELSE 0 END), 0)"),
               Arel.sql("COALESCE(SUM(CASE WHEN issued_at <  #{q_start} THEN value ELSE 0 END), 0)")
             )
             .each { |id, cur, pre| data[id].merge!(inv_cur: cur, inv_pre: pre) }

      # Recebimentos (<= fim do período) por CC: no período, total, e sobre NFs
      # anteriores. rec_on_pre conta só pagamentos ATÉ antes do período,
      # ignorando pagamentos no período selecionado/futuro.
      Receipt.joins(:invoice)
             .where(invoices: { cost_center_id: cc_ids })
             .where("receipts.payment_date <= #{q_end}")
             .group("invoices.cost_center_id")
             .pluck(
               Arel.sql("invoices.cost_center_id"),
               Arel.sql("COALESCE(SUM(CASE WHEN receipts.payment_date >= #{q_start} THEN receipts.value ELSE 0 END), 0)"),
               Arel.sql("COALESCE(SUM(receipts.value), 0)"),
               Arel.sql("COALESCE(SUM(CASE WHEN invoices.issued_at < #{q_start} AND receipts.payment_date < #{q_start} THEN receipts.value ELSE 0 END), 0)")
             )
             .each { |id, cur, until_end, on_pre| data[id].merge!(rec_cur: cur, rec_until: until_end, rec_on_pre: on_pre) }

      @scope.includes(:client).joins(:client)
            .where(id: data.keys)
            .order("clients.name", "cost_centers.cr_code")
            .filter_map { |cc| build_row(cc, data[cc.id]) }
    end

    def build_row(cost_center, d)
      inv_cur = d[:inv_cur] || 0
      inv_pre = d[:inv_pre] || 0

      row = {
        cc:       cost_center,
        client:   cost_center.client,
        previsto: d[:previsto] || 0,
        inv_cur:  inv_cur,
        inv_pre:  inv_pre,
        open_pre: inv_pre - (d[:rec_on_pre] || 0),
        rec_cur:  d[:rec_cur] || 0,
        open:     (inv_cur + inv_pre) - (d[:rec_until] || 0)
      }

      # Omite CCs com TODOS os valores exibidos zerados.
      row unless DISPLAY_KEYS.all? { |k| row[k].to_d.zero? }
    end

    # Rótulos "MÊS/AAAA" de cada mês do intervalo (previsto é acumulado no período).
    def month_year_labels
      labels = []
      cursor = @period_start.beginning_of_month
      while cursor <= @period_end
        labels << ForecastEntry.month_year_for(cursor)
        cursor = cursor.next_month
      end
      labels
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
