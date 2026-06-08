require "roo"

module Imports
  # Importação tolerante a erros, com detecção de colunas por CABEÇALHO.
  #
  # Em vez de posições fixas, localiza cada coluna pelo nome do cabeçalho — assim
  # funciona com o MODELO_RECEITAS real e com o template limpo, e remover/reordenar
  # colunas não quebra a importação.
  #
  # - UPSERT (cria se novo, atualiza campos presentes se já existe).
  # - Enriquece o CC com OBJETO / DATA FINAL / COORDENADOR a partir da PREVISÃO.
  # - Participação aceita 0–1 (fração) ou 0–100 (percentual): valor > 1 é dividido por 100.
  # - Coordenadores múltiplos separados por "/".
  # - Importa observações; recebimento deduplicado por (NF, data, valor).
  class ExcelImporter
    Result = Struct.new(:created, :updated, :errors, :fatal_error, keyword_init: true) do
      def imported     = created + updated
      def success?     = fatal_error.nil?
      def partial?     = errors.any?
      def fully_clean? = fatal_error.nil? && errors.empty?
    end

    SHEETS = {
      cost_centers: "CADASTRO CENTRO DE CUSTO",
      forecasts:    "PREVISAO FATURAMENTO",
      invoices:     "FATURAMENTO",
      receipts:     "RECEBIMENTO"
    }.freeze

    PT_MONTHS = ForecastEntry::PT_MONTHS

    def initialize(file_path)
      @file_path = file_path
      @errors    = []
      @created   = 0
      @updated   = 0
    end

    def call
      workbook = Roo::Spreadsheet.open(@file_path.to_s)
      import_cost_centers(workbook)
      import_forecasts(workbook)
      import_invoices(workbook)
      import_receipts(workbook)
      Result.new(created: @created, updated: @updated, errors: @errors, fatal_error: nil)
    rescue => e
      Result.new(created: @created, updated: @updated, errors: @errors,
                 fatal_error: "Não foi possível processar o arquivo: #{e.message}")
    end

    private

    # ── CADASTRO (CR, Part, Descrição, Cliente, Objeto, Data Final, Coordenador) ──
    def import_cost_centers(wb)
      sheet, idx = open_sheet(wb, :cost_centers,
        anchor: %w[DESCRI CLIENTE],
        columns: {
          cr: %w[CR CENTRO], participation: %w[PART], description: %w[DESCRI],
          client: %w[CLIENTE CLEIENTE], object_text: %w[OBJETO],
          contract_number: %w[CONTRATO], start_date: %w[INICIO INÍCIO],
          end_date: %w[FINAL FIM], value: %w[VALOR], coordinator: %w[COORDENADOR GESTOR]
        })
      return unless sheet

      each_data_row(sheet, idx[:header_row]) do |row, line|
        cr = val(row, idx[:cr])
        next if cr.blank?
        description = val(row, idx[:description])
        client_name = val(row, idx[:client])
        next if description.blank? && client_name.blank? # linha de seção

        upsert_cost_center(cr, line: line,
          participation: participation(val(row, idx[:participation])),
          description: description, client_name: client_name,
          object_text: val(row, idx[:object_text]),
          contract_number: val(row, idx[:contract_number]),
          start_date: parse_date(raw(row, idx[:start_date])),
          end_date: parse_date(raw(row, idx[:end_date])),
          value: parse_amount(val(row, idx[:value])),
          coordinator: val(row, idx[:coordinator]))
      end
    end

    # ── PREVISÃO (enxuta): CR, Mês/Ano, Previsto, Observação ─────────────────────
    # Demais dados (objeto, data final, coordenador) ficam no CADASTRO do CC.
    # Realizado NÃO é importado — é derivado do faturamento.
    def import_forecasts(wb)
      sheet, idx = open_sheet(wb, :forecasts,
        anchor: %w[PREVISTO COMPET MES OBJETO],
        columns: {
          cr: %w[CR CENTRO], month: %w[MES COMPET ANO], previsto: %w[PREVISTO],
          observations: %w[OBSERVA OBS]
        })
      return unless sheet

      sheet_month = find_month_year(sheet) # fallback se não houver coluna de mês/ano

      each_data_row(sheet, idx[:header_row]) do |row, line|
        cr = val(row, idx[:cr])
        next if cr.blank?

        month_year = parse_month_year(val(row, idx[:month])) || sheet_month
        next if month_year.blank?

        cc = CostCenter.find_by(cr_code: cr)
        if cc.nil?
          @errors << "Previsão — linha #{line} (CR #{cr}): centro de custo não encontrado (cadastre-o na aba CADASTRO)."
          next
        end

        fe = ForecastEntry.find_or_initialize_by(cost_center: cc, month_year: month_year)
        was_new = fe.new_record?
        fe.forecasted_total = val(row, idx[:previsto]).to_f
        obs = val(row, idx[:observations]); fe.observations = obs if obs.present?
        persist(fe, was_new, "Previsão", line, "CR #{cr}")
      end
    end

    # ── FATURAMENTO ──────────────────────────────────────────────────────────────
    def import_invoices(wb)
      sheet, idx = open_sheet(wb, :invoices,
        anchor: %w[VALOR NOTA],
        columns: {
          nf: %w[NF NOTA], cr: %w[CR CENTRO], client: %w[CLIENTE CLEIENTE],
          issued_at: %w[EMISSAO DATA], value: %w[VALOR], observations: %w[OBSERVA OBS],
          kind: %w[TIPO PRINCIPAL REAJUSTE]
        })
      return unless sheet

      each_data_row(sheet, idx[:header_row]) do |row, line|
        nf = val(row, idx[:nf]); cr = val(row, idx[:cr])
        next if nf.blank? || cr.blank?

        cc = CostCenter.find_by(cr_code: cr)
        if cc.nil?
          @errors << "Faturamento — linha #{line} (NF #{nf}): centro de custo #{cr} não encontrado."
          next
        end
        issued_at = parse_date(raw(row, idx[:issued_at]))
        if issued_at.nil?
          @errors << "Faturamento — linha #{line} (NF #{nf}): data de emissão inválida ou vazia."
          next
        end

        inv = Invoice.find_or_initialize_by(cost_center: cc, number: nf)
        was_new = inv.new_record?
        # Cliente derivado do CC (coluna removida do modelo); usa a coluna se existir.
        client_name = val(row, idx[:client]).presence || cc.client&.name
        inv.client_name  = client_name if client_name.present? || inv.client_name.blank?
        inv.issued_at    = issued_at
        inv.value        = parse_amount(val(row, idx[:value]))
        inv.kind         = reajuste?(val(row, idx[:kind])) ? :reajuste : :principal
        obs = val(row, idx[:observations]); inv.observations = obs if obs.present?
        persist(inv, was_new, "Faturamento", line, "NF #{nf}")
      end
    end

    # ── RECEBIMENTO ──────────────────────────────────────────────────────────────
    def import_receipts(wb)
      sheet, idx = open_sheet(wb, :receipts,
        anchor: %w[BAIXA RECEBIDO],
        columns: {
          nf: %w[NF NOTA], cr: %w[CR CENTRO], payment_date: %w[BAIXA DATA],
          value: %w[RECEBIDO VALOR], observations: %w[OBSERVA OBS]
        })
      return unless sheet

      each_data_row(sheet, idx[:header_row]) do |row, line|
        nf = val(row, idx[:nf]); cr = val(row, idx[:cr])
        next if nf.blank? || cr.blank?

        cc      = CostCenter.find_by(cr_code: cr)
        invoice = Invoice.find_by(cost_center: cc, number: nf)
        if invoice.nil?
          @errors << "Recebimento — linha #{line} (NF #{nf}): nota fiscal não encontrada para o CR #{cr}."
          next
        end
        payment_date = parse_date(raw(row, idx[:payment_date]))
        if payment_date.nil?
          @errors << "Recebimento — linha #{line} (NF #{nf}): data de baixa inválida ou vazia."
          next
        end
        value = val(row, idx[:value]).to_f
        next if value <= 0

        rec = Receipt.find_or_initialize_by(invoice: invoice, payment_date: payment_date, value: value)
        was_new = rec.new_record?
        obs = val(row, idx[:observations]); rec.observations = obs if obs.present?
        persist(rec, was_new, "Recebimento", line, "NF #{nf}")
      end
    end

    # ── Detecção de colunas / leitura ───────────────────────────────────────────

    # Abre a aba e detecta a linha de cabeçalho + índice de cada coluna.
    def open_sheet(wb, key, anchor:, columns:)
      sheet = wb.sheet(SHEETS[key])
      header_row, map = detect_columns(sheet, anchor, columns)
      if header_row.nil?
        @errors << "Aba \"#{SHEETS[key]}\": cabeçalho não reconhecido."
        return [nil, {}]
      end
      [sheet, map.merge(header_row: header_row)]
    rescue => e
      @errors << "Aba \"#{SHEETS[key]}\": não foi possível ler (#{e.message})."
      [nil, {}]
    end

    def detect_columns(sheet, anchor, columns)
      max = [sheet.last_row || 0, 20].min
      (1..max).each do |r|
        headers = sheet.row(r).map { |c| norm(c) }
        next unless headers.any? { |h| anchor.any? { |a| match?(h, a) } }

        idx = {}
        columns.each do |key, syns|
          syns.each do |s|
            pos = headers.index { |h| h.present? && match?(h, s) }
            if pos
              idx[key] = pos
              break
            end
          end
        end
        return [r, idx]
      end
      [nil, {}]
    end

    # Match: igualdade exata (para siglas curtas como "CR") ou inclusão (palavras).
    def match?(header, synonym)
      header == synonym || (synonym.length > 3 && header.include?(synonym))
    end

    def each_data_row(sheet, header_row)
      (header_row + 1).upto(sheet.last_row || 0) do |line|
        row = sheet.row(line)
        next if row.nil?
        yield row, line
      end
    end

    def find_month_year(sheet)
      max = [sheet.last_row || 0, 8].min
      (1..max).each do |r|
        sheet.row(r).each do |c|
          my = parse_month_year(c)
          return my if my
        end
      end
      nil
    end

    # Converte o valor da célula em "JUNHO/2025". Aceita:
    #   - Date/Time (o roo converte células formatadas como data) → usa mês/ano
    #   - "2025-06" / "2025-06-01" (ISO, mês ou data completa)
    #   - "06/2025" / "6-2025" (MM/AAAA) e "06/25" (MM/AA → 20AA)
    #   - "JUNHO/2025" e "JUNHO DE 2025" (escrito)
    def parse_month_year(value)
      # Célula que o roo entregou como data (ou datetime) — caso mais comum de bug.
      if value.respond_to?(:month) && value.respond_to?(:year)
        return month_year_str(value.month, value.year)
      end

      s = value.to_s.strip
      return nil if s.blank?

      if (m = s.match(%r{\A(\d{4})[/\-.](\d{1,2})(?:[/\-.]\d{1,2})?\z})) # ISO: AAAA-MM[-DD]
        return month_year_str(m[2].to_i, m[1].to_i)
      end
      if (m = s.match(%r{\A(\d{1,2})[/\-.](\d{4})\z}))                   # MM/AAAA
        return month_year_str(m[1].to_i, m[2].to_i)
      end
      if (m = s.match(%r{\A(\d{1,2})[/\-.](\d{2})\z}))                   # MM/AA
        return month_year_str(m[1].to_i, 2000 + m[2].to_i)
      end

      up = norm(s)
      if (m = up.match(%r{\A([A-Z]+)(?:[ /\-]+|[ ]+DE[ ]+)(\d{4})\z}))   # JUNHO/2025, JUNHO DE 2025
        i = PT_MONTHS.map { |mo| norm(mo) }.index(m[1])
        return month_year_str(i + 1, m[2].to_i) if i
      end
      nil
    end

    def month_year_str(month, year)
      return nil unless (1..12).cover?(month) && year.to_i.positive?
      "#{PT_MONTHS[month - 1]}/#{year}"
    end

    # ── Upsert / persistência ───────────────────────────────────────────────────
    def upsert_cost_center(cr_code, line:, participation: nil, description: nil,
                           client_name: nil, object_text: nil, end_date: nil, coordinator: nil,
                           contract_number: nil, start_date: nil, value: nil)
      cc = CostCenter.find_or_initialize_by(cr_code: cr_code)
      was_new = cc.new_record?

      if client_name.present? && cc.client.nil?
        cc.client = Client.find_or_create_by!(name: client_name) { |c| c.full_name = client_name }
      elsif cc.client.nil?
        cc.client = Client.find_or_create_by!(name: "NÃO INFORMADO") { |c| c.full_name = "NÃO INFORMADO" }
      end
      cc.participation    = participation if participation && participation.positive? && participation <= 1
      cc.description      = description     if description.present?
      cc.object_text      = object_text    if object_text.present?
      cc.end_date         = end_date       if end_date.present?
      cc.coordinator      = coordinator    if coordinator.present?
      cc.contract_number  = contract_number if contract_number.present?
      cc.start_date       = start_date     if start_date.present?
      cc.value            = value          if value && value.positive?

      status = persist(cc, was_new, "Centro de Custo", line, "CR #{cr_code}")
      [cc, status]
    rescue => e
      @errors << "Centro de Custo — linha #{line} (CR #{cr_code}): #{e.message}"
      [nil, :error]
    end

    def persist(record, was_new, label, line, ident)
      return :unchanged unless record.new_record? || record.changed?

      record.save!
      was_new ? (@created += 1; :created) : (@updated += 1; :updated)
    rescue => e
      @errors << "#{label} — linha #{line} (#{ident}): #{e.message}"
      :error
    end

    # ── Helpers de célula ────────────────────────────────────────────────────────
    def raw(row, idx)
      idx ? row[idx] : nil
    end

    def val(row, idx)
      raw(row, idx).to_s.strip
    end

    def norm(value)
      value.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").upcase.strip
    end

    # Aceita 0–1 (fração) ou 0–100 (percentual): > 1 vira fração.
    def participation(text)
      v = text.to_f
      return nil if v.zero?
      v > 1 ? (v / 100.0) : v
    end

    # Converte texto monetário em float (aceita "1.234,56" pt-BR ou "1234.56").
    def parse_amount(text)
      s = text.to_s.strip
      return 0.0 if s.blank?
      s = s.delete(".").tr(",", ".") if s =~ /,\d{1,2}\z/
      s.to_f
    end

    def reajuste?(text)
      norm(text).include?("REAJUSTE")
    end

    def parse_date(rawval)
      return nil if rawval.blank?
      return rawval if rawval.is_a?(Date)

      numeric = rawval.to_f
      return nil if numeric.zero?

      Date.new(1899, 12, 30) + numeric.to_i
    rescue
      nil
    end
  end
end
