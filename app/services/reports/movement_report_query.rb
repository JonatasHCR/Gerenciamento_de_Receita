module Reports
  # Relatório de Movimentação: FATURAMENTO (por data de emissão) e/ou
  # RECEBIMENTO (por data de baixa), agrupado conforme o Reports::ScopeFilter.
  #
  #   Reports::MovementReportQuery.new(filter:, tipo: :ambos,
  #                                    period_start:, period_end:, only_open:).call
  #
  # O recebido/em aberto é um SNAPSHOT no fim do período: baixa posterior ao
  # corte não conta (NF paga dia 15 aparece em aberto num relatório até o 14).
  #
  # `only_open: true` + `tipo: :faturamento` sem período reproduz a antiga
  # "Relação das Faturas em Aberto".
  class MovementReportQuery
    TIPOS    = %i[faturamento recebimento ambos].freeze
    MAX_ROWS = 20_000

    FATURAMENTO_SUMS = %i[value received balance].freeze
    RECEBIMENTO_SUMS = %i[value].freeze

    def initialize(filter:, tipo: :ambos, period_start: nil, period_end: nil, only_open: false)
      @filter       = filter
      @tipo         = TIPOS.include?(tipo.to_s.to_sym) ? tipo.to_s.to_sym : :ambos
      @period_start = period_start
      @period_end   = period_end
      @only_open    = ActiveModel::Type::Boolean.new.cast(only_open) || false
    end

    def call
      sections = []
      sections << faturamento_section if @tipo.in?(%i[faturamento ambos])
      sections << recebimento_section if @tipo.in?(%i[recebimento ambos])

      {
        tipo:         @tipo,
        group_by:     @filter.group_by,
        levels:       levels,
        period_start: @period_start,
        period_end:   @period_end,
        only_open:    @only_open,
        sections:     sections,
        summary:      summary(sections)
      }
    end

    private

    def levels
      @levels ||= @filter.levels
    end

    def period_range
      return nil if @period_start.blank? && @period_end.blank?
      (@period_start || Date.new(1900, 1, 1))..(@period_end || Date.new(2999, 12, 31))
    end

    # --- Faturamento (data de emissão) ---------------------------------------
    #
    # A seção é montada em BLOCOS renderizados dentro de cada centro de custo:
    #   tipo faturamento          → um bloco só, com o VALOR faturado (sem em
    #     aberto e sem sinalização — é uma relação de faturamento).
    #   tipo faturamento + só em  → troca o VALOR pelo EM ABERTO e sinaliza os
    #     aberto                     recebimentos parciais.
    #   tipo ambos                → bloco 1 com as NFs que tiveram baixa (VALOR =
    #     recebido, DT BAIXA = última baixa) + "Total recebido"; bloco 2 com o
    #     que falta receber, com a DT BAIXA sempre em branco (o valor ainda não
    #     foi recebido); só as parciais são sinalizadas.

    FATURAMENTO_LABELS      = { value: "Faturado", received: "Recebido", balance: "Em aberto" }.freeze
    FATURAMENTO_LEAF_LABELS = { value: "Total faturado", received: "Total recebido",
                                balance: "Total em aberto" }.freeze
    RECEBIMENTO_LABELS      = { value: "Recebido" }.freeze
    RECEBIMENTO_LEAF_LABELS = { value: "Total recebido" }.freeze

    def faturamento_section
      {
        kind:            :faturamento,
        title:           faturamento_title,
        total_title:     "TOTAL",
        columns:         faturamento_columns,
        headers:         @tipo == :ambos ? { received: "VALOR" } : {},
        blocks:          faturamento_blocks,
        # Linha final de cada centro de custo e subtotais dos níveis acima.
        leaf_total_keys: faturamento_total_keys,
        leaf_labels:     FATURAMENTO_LEAF_LABELS,
        total_columns:   @tipo == :ambos ? %i[value received balance] : faturamento_total_keys,
        total_labels:    FATURAMENTO_LABELS,
        truncated:       @invoices_truncated,
        tree:            GroupTree.build(invoice_rows, levels: levels, sum_keys: FATURAMENTO_SUMS)
      }
    end

    def faturamento_title
      return "Faturamento e recebimentos" if @tipo == :ambos
      @only_open ? "Faturas em aberto" : "Faturamento (por data de emissão)"
    end

    def faturamento_columns
      return %i[number issued_at last_payment cr_code contract_number received] if @tipo == :ambos
      return %i[number issued_at cr_code contract_number balance]               if @only_open
      %i[number issued_at cr_code contract_number value]
    end

    def faturamento_total_keys
      return %i[value balance] if @tipo == :ambos
      @only_open ? %i[balance] : %i[value]
    end

    def faturamento_blocks
      return ambos_blocks if @tipo == :ambos

      # Só em aberto: sinaliza parcial × sem nenhum recebimento. Relação normal
      # de faturamento não sinaliza nada.
      [{ key: :faturado, title: nil, scope: :all,
         amount: @only_open ? :balance : :value,
         # Sinaliza só o recebimento parcial: numa lista que já é toda de
         # faturas em aberto, marcar as sem recebimento não diz nada.
         flags: @only_open ? %i[partial] : [], total_keys: [] }]
    end

    def ambos_blocks
      [
        { key: :recebido, title: nil, scope: :received, amount: :received,
          flags: %i[partial], total_keys: %i[received] },
        # O valor aqui é o que AINDA NÃO foi recebido, então a DT BAIXA fica em
        # branco em todas as linhas — inclusive nas parciais.
        { key: :em_aberto, title: "Em aberto (parcial ou sem recebimento)", scope: :open,
          amount: :balance, blank_columns: %i[last_payment],
          flags: %i[partial], total_keys: [] }
      ]
    end

    def invoice_rows
      @invoice_rows ||= begin
        invoices = load_invoices
        @invoices_truncated = truncate!(invoices)
        invoices.map { |inv| invoice_row(inv) }
      end
    end

    def load_invoices
      rel = Invoice.with_received(@period_end)
                   .where(cost_center_id: @filter.cost_centers.reselect(:id))
      rel = rel.where(issued_at: period_range) if period_range
      # O LEFT JOIN já veio de with_received (com o corte). Usar
      # `with_open_balance` aqui criaria um segundo join com o mesmo alias.
      rel = rel.where("invoices.value > COALESCE(r.received, 0)") if @only_open
      rel.preload(cost_center: :client).order(:issued_at, :number).limit(MAX_ROWS + 1).to_a
    end

    def invoice_row(inv)
      received = inv.received_amount
      balance  = inv.balance
      {
        invoice: inv, cc: inv.cost_center, client: inv.cost_center&.client,
        number: inv.number, issued_at: inv.issued_at,
        # Data da ÚLTIMA baixa (até o corte); em branco quando não houve nenhuma.
        last_payment: received > 0 ? inv[:preloaded_last_payment] : nil,
        cr_code: inv.cost_center&.cr_code, contract_number: inv.cost_center&.contract_number,
        value: inv.value, received: received, balance: balance > 0 ? balance : 0,
        partial: received > 0 && balance > 0, open: balance > 0
      }
    end

    # --- Recebimento (data de baixa) -----------------------------------------

    def recebimento_section
      receipts  = load_receipts
      truncated = truncate!(receipts)
      rows      = receipts.map { |rec| receipt_row(rec) }

      {
        kind:            :recebimento,
        title:           "Recebimentos (por data de baixa)",
        total_title:     "TOTAL",
        columns:         %i[number payment_date cr_code contract_number value],
        leaf_total_keys: %i[value],
        leaf_labels:     RECEBIMENTO_LEAF_LABELS,
        total_columns:   %i[value],
        total_labels:    RECEBIMENTO_LABELS,
        truncated:       truncated,
        tree:            GroupTree.build(rows, levels: levels, sum_keys: RECEBIMENTO_SUMS)
      }
    end

    def load_receipts
      rel = Receipt.joins(:invoice)
                   .where(invoices: { cost_center_id: @filter.cost_centers.reselect(:id) })
      rel = rel.where(payment_date: period_range) if period_range
      rel.preload(invoice: { cost_center: :client })
         .order(:payment_date, :id).limit(MAX_ROWS + 1).to_a
    end

    def receipt_row(rec)
      cc = rec.invoice&.cost_center
      {
        receipt: rec, invoice: rec.invoice, cc: cc, client: cc&.client,
        number: rec.invoice&.number, payment_date: rec.payment_date,
        cr_code: cc&.cr_code, contract_number: cc&.contract_number,
        value: rec.value, observations: rec.observations
      }
    end

    # --- Resumo --------------------------------------------------------------

    # Totais vindos da RAIZ de cada árvore (calculados sobre as linhas planas),
    # então um CC com 2 coordenadores não é contado duas vezes.
    def summary(sections)
      fat = sections.find { |s| s[:kind] == :faturamento }&.dig(:tree, :totals) || {}
      rec = sections.find { |s| s[:kind] == :recebimento }&.dig(:tree, :totals) || {}

      { faturado: fat[:value] || 0, em_aberto: fat[:balance] || 0,
        recebido: rec[:value] || 0, recebido_nas_nfs: fat[:received] || 0,
        nfs: fat[:count] || 0, baixas: rec[:count] || 0 }
    end

    # A query pede MAX_ROWS + 1: se veio a linha extra, o resultado foi cortado.
    def truncate!(collection)
      return false if collection.size <= MAX_ROWS
      collection.pop(collection.size - MAX_ROWS)
      true
    end
  end
end
