class DashboardController < ApplicationController
  def index
    skip_authorization
    @month = parse_month(params[:month])

    if current_user.admin_or_financeiro?
      m_start = @month.beginning_of_month
      m_end   = @month.end_of_month

      # ── KPI "Em Aberto" — SNAPSHOT até o fim do mês selecionado ─────────────
      # Em aberto = NFs emitidas (<= fim do mês) − recebimentos pagos (<= fim do mês).
      # Recebimentos são limitados ao fim do mês para que pagamentos de meses
      # anteriores reduzam o saldo conforme o mês avança.
      conn     = ActiveRecord::Base.connection
      m_from_q = conn.quote(m_start)
      m_to_q   = conn.quote(m_end)
      received_join = <<~SQL.squish
        LEFT JOIN (
          SELECT invoice_id, SUM(value) AS received
          FROM receipts WHERE payment_date <= #{m_to_q}
          GROUP BY invoice_id
        ) r ON r.invoice_id = invoices.id
      SQL
      balance_expr = "invoices.value - COALESCE(r.received, 0)"

      stats = Invoice
        .where("invoices.issued_at <= #{m_to_q}")
        .joins(received_join)
        .where("#{balance_expr} > 0")
        .pick(
          Arel.sql("COALESCE(SUM(#{balance_expr}), 0)"),
          Arel.sql("COUNT(*)"),
          Arel.sql("COALESCE(SUM(CASE WHEN invoices.issued_at BETWEEN #{m_from_q} AND #{m_to_q} THEN #{balance_expr} ELSE 0 END), 0)"),
          Arel.sql("COUNT(CASE WHEN invoices.issued_at BETWEEN #{m_from_q} AND #{m_to_q} THEN 1 END)"),
          Arel.sql("COALESCE(SUM(CASE WHEN invoices.issued_at < #{m_from_q} THEN #{balance_expr} ELSE 0 END), 0)"),
          Arel.sql("COUNT(CASE WHEN invoices.issued_at < #{m_from_q} THEN 1 END)")
        ).map { |v| v || 0 }

      @open_balance,
      @open_invoices_count,
      @open_balance_current_month,
      @open_invoices_current_month_count,
      @open_balance_previous_months,
      @open_invoices_previous_months_count = stats

      chart_start = Date.new(@month.year, 1, 1)
      chart_end   = m_end

      @chart_months = @month.month
      @chart_year   = @month.year

      chart_range = chart_start..chart_end

      @invoices_by_month = Invoice
        .where(issued_at: chart_range)
        .group_by_month(:issued_at, format: "%m/%Y", range: chart_range)
        .sum(:value)
        .transform_keys { |k| pt_month_label(k) }

      @receipts_by_month = Receipt
        .where(payment_date: chart_range)
        .group_by_month(:payment_date, format: "%m/%Y", range: chart_range)
        .sum(:value)
        .transform_keys { |k| pt_month_label(k) }

      # Soma corrida (running total) sobre os meses já ordenados: cada ponto acumula
      # de janeiro até aquele mês. Mantém todos os meses, sem juntar/excluir.
      running = 0
      @receipts_accumulated = @receipts_by_month.transform_values { |v| running += v }

      # ── Faturado × Recebido por cliente/CC ─────────────────────────────────
      # Faturamento agregado por CC numa única query (mês atual × anteriores).
      invoice_rows = Invoice
        .where("issued_at <= #{m_to_q}")
        .group(:cost_center_id)
        .pluck(
          :cost_center_id,
          Arel.sql("COALESCE(SUM(CASE WHEN issued_at >= #{m_from_q} THEN value ELSE 0 END), 0)"),
          Arel.sql("COALESCE(SUM(CASE WHEN issued_at <  #{m_from_q} THEN value ELSE 0 END), 0)")
        )

      # Recebimentos (até o fim do mês) agregados por CC numa única query:
      # recebido no mês, recebido total e recebido sobre NFs anteriores.
      # rec_on_pre considera apenas pagamentos feitos ATÉ o mês anterior
      # (payment_date < início do mês), ignorando pagamentos no mês selecionado/futuro.
      receipt_rows = Receipt.joins(:invoice)
        .where("receipts.payment_date <= #{m_to_q}")
        .group("invoices.cost_center_id")
        .pluck(
          Arel.sql("invoices.cost_center_id"),
          Arel.sql("COALESCE(SUM(CASE WHEN receipts.payment_date >= #{m_from_q} THEN receipts.value ELSE 0 END), 0)"),
          Arel.sql("COALESCE(SUM(receipts.value), 0)"),
          Arel.sql("COALESCE(SUM(CASE WHEN invoices.issued_at < #{m_from_q} AND receipts.payment_date < #{m_from_q} THEN receipts.value ELSE 0 END), 0)")
        )

      bdata = Hash.new { |h, k| h[k] = {} }
      invoice_rows.each { |cc_id, inv_cur, inv_pre| bdata[cc_id].merge!(inv_cur: inv_cur, inv_pre: inv_pre) }
      receipt_rows.each { |cc_id, rec_cur, rec_until, rec_on_pre| bdata[cc_id].merge!(rec_cur: rec_cur, rec_until: rec_until, rec_on_pre: rec_on_pre) }

      # Totais do mês (KPI) derivados sem novas queries.
      @total_invoiced = bdata.values.sum { |d| d[:inv_cur] || 0 }
      @total_received = bdata.values.sum { |d| d[:rec_cur] || 0 }

      @billing_by_client = {}
      CostCenter.includes(:client)
                .where(id: bdata.keys)
                .joins(:client)
                .order("clients.name", "cost_centers.cr_code")
                .each do |cc|
        d          = bdata[cc.id]
        inv_cur    = d[:inv_cur]    || 0
        inv_pre    = d[:inv_pre]    || 0
        rec_cur    = d[:rec_cur]    || 0
        rec_until  = d[:rec_until]  || 0
        rec_on_pre = d[:rec_on_pre] || 0
        inv_total  = inv_cur + inv_pre
        @billing_by_client[cc.client] ||= []
        @billing_by_client[cc.client] << {
          cc:        cc,
          inv_cur:   inv_cur,
          rec_cur:   rec_cur,
          inv_pre:   inv_pre,
          open_pre:  inv_pre - rec_on_pre,  # em aberto das NFs anteriores (pago só até o mês anterior)
          inv_total: inv_total,
          rec_total: rec_until,             # total recebido até o fim do mês
          open:      inv_total - rec_until  # em aberto até o fim do mês
        }
      end

      # Oculta CC só quando NÃO há nada a mostrar: total faturado == total recebido
      # (nada em aberto) E sem movimento no mês (faturado/recebido) E sem aberto
      # anterior. Assim, CC com movimento no mês aparece mesmo que tenha sido quitado.
      @billing_by_client.each_value do |entries|
        entries.reject! do |e|
          e[:inv_total] == e[:rec_total] &&
            e[:inv_cur].zero? && e[:rec_cur].zero? && e[:open_pre].zero?
        end
      end
      @billing_by_client.reject! { |_client, entries| entries.empty? }
    end

    @forecast_summary = Forecasts::SummaryQuery.new(
      month_year: pt_month_year(@month),
      scope: policy_scope(ForecastEntry)
    ).call
    # Oculta clientes cujas previsões e realizados estão todos zerados.
    @forecast_summary = @forecast_summary.reject do |_client, entries|
      entries.sum(&:forecasted_total).zero? && entries.sum(&:realized_total).zero?
    end
  end
end
