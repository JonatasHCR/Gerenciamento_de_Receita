require "roo"

module Imports
  # Importação tolerante a erros: processa todas as linhas válidas, grava as que
  # dão certo e coleta os erros (com aba + número da linha + motivo) das que falham.
  # Uma aba ausente/corrompida não impede a importação das demais.
  class ExcelImporter
    Result = Struct.new(:imported, :errors, :fatal_error, keyword_init: true) do
      def success?      = fatal_error.nil?          # processo rodou (arquivo lido)
      def partial?      = errors.any?               # houve linhas com erro
      def fully_clean?  = fatal_error.nil? && errors.empty?
    end

    SHEETS = {
      cost_centers: "CADASTRO CENTRO DE CUSTO",
      invoices:     "FATURAMENTO",
      receipts:     "RECEBIMENTO",
      forecasts:    "PREVISAO FATURAMENTO"
    }.freeze

    def initialize(file_path)
      @file_path = file_path
      @errors    = []
      @imported  = 0
    end

    def call
      workbook = Roo::Spreadsheet.open(@file_path.to_s)
      import_cost_centers(workbook)
      import_invoices(workbook)
      import_receipts(workbook)
      import_forecasts(workbook)
      Result.new(imported: @imported, errors: @errors, fatal_error: nil)
    rescue => e
      # Erro fatal: não foi possível abrir/ler o arquivo. Mantém o que já foi gravado.
      Result.new(imported: @imported, errors: @errors,
                 fatal_error: "Não foi possível processar o arquivo: #{e.message}")
    end

    private

    # Percorre uma aba com tolerância: aba ausente vira um erro (não fatal),
    # e cada linha é numerada para facilitar a localização.
    def each_sheet_row(wb, key, offset:)
      sheet = wb.sheet(SHEETS[key])
      line  = offset
      sheet.each_row_streaming(offset: offset, pad_cells: true) do |row|
        line += 1
        yield row, line
      end
    rescue => e
      @errors << "Aba \"#{SHEETS[key]}\": não foi possível ler (#{e.message})."
    end

    def import_cost_centers(wb)
      each_sheet_row(wb, :cost_centers, offset: 4) do |row, line|
        next if row[0].nil? || row[0].value.blank?

        cr_code = row[1]&.value&.to_s&.strip
        next if cr_code.blank?

        client_name = row[4]&.value&.to_s&.strip
        next if client_name.blank?

        client = Client.find_or_create_by!(name: client_name) do |c|
          c.full_name = client_name
        end

        cc = CostCenter.find_or_create_by!(cr_code: cr_code) do |center|
          center.description   = row[3]&.value&.to_s&.strip || ""
          center.participation = row[2]&.value.to_f || 1.0
          center.coordinator   = row[6]&.value&.to_s&.strip || ""
          center.client        = client
        end
        @imported += 1 if cc.previously_new_record?
      rescue => e
        @errors << "Centro de Custo — linha #{line} (CR #{cr_code.presence || '?'}): #{e.message}"
      end
    end

    def import_invoices(wb)
      each_sheet_row(wb, :invoices, offset: 5) do |row, line|
        cr_code   = row[3]&.value&.to_s&.strip
        nf_number = row[2]&.value&.to_s&.strip
        next if cr_code.blank? || nf_number.blank?

        cost_center = CostCenter.find_by(cr_code: cr_code)
        if cost_center.nil?
          @errors << "Faturamento — linha #{line} (NF #{nf_number}): centro de custo #{cr_code} não encontrado."
          next
        end

        issued_at = parse_excel_date(row[5]&.value)
        if issued_at.nil?
          @errors << "Faturamento — linha #{line} (NF #{nf_number}): data de emissão inválida ou vazia."
          next
        end

        inv = Invoice.find_or_create_by!(cost_center: cost_center, number: nf_number) do |invoice|
          invoice.client_name = row[4]&.value&.to_s&.strip || ""
          invoice.issued_at   = issued_at
          invoice.value       = row[6]&.value.to_f
        end
        @imported += 1 if inv.previously_new_record?
      rescue => e
        @errors << "Faturamento — linha #{line} (NF #{nf_number.presence || '?'}): #{e.message}"
      end
    end

    def import_receipts(wb)
      each_sheet_row(wb, :receipts, offset: 5) do |row, line|
        nf_number = row[1]&.value&.to_s&.strip
        cr_code   = row[2]&.value&.to_s&.strip
        next if nf_number.blank? || cr_code.blank?

        cost_center = CostCenter.find_by(cr_code: cr_code)
        invoice     = Invoice.find_by(cost_center: cost_center, number: nf_number)
        if invoice.nil?
          @errors << "Recebimento — linha #{line} (NF #{nf_number}): nota fiscal não encontrada para o CR #{cr_code}."
          next
        end

        payment_date = parse_excel_date(row[4]&.value)
        if payment_date.nil?
          @errors << "Recebimento — linha #{line} (NF #{nf_number}): data de baixa inválida ou vazia."
          next
        end

        receipt_value = row[5]&.value.to_f
        next if receipt_value <= 0

        Receipt.create!(invoice: invoice, payment_date: payment_date, value: receipt_value)
        @imported += 1
      rescue => e
        @errors << "Recebimento — linha #{line} (NF #{nf_number.presence || '?'}): #{e.message}"
      end
    end

    def import_forecasts(wb)
      sheet = begin
        wb.sheet(SHEETS[:forecasts])
      rescue => e
        @errors << "Aba \"#{SHEETS[:forecasts]}\": não foi possível ler (#{e.message})."
        return
      end
      month_year = sheet.cell(3, 9).to_s.strip

      each_sheet_row(wb, :forecasts, offset: 5) do |row, line|
        cr_code = row[1]&.value&.to_s&.strip
        next if cr_code.blank?

        cost_center = CostCenter.find_by(cr_code: cr_code)
        if cost_center.nil?
          @errors << "Previsão — linha #{line} (CR #{cr_code}): centro de custo não encontrado."
          next
        end

        # realized_total é derivado do faturamento (before_validation no model).
        fe = ForecastEntry.find_or_create_by!(cost_center: cost_center, month_year: month_year) do |entry|
          entry.forecasted_total   = row[9]&.value.to_f
          entry.forecasted_pct_ufc = row[10]&.value.to_f
          entry.realized_pct_ufc   = row[12]&.value.to_f
        end
        @imported += 1 if fe.previously_new_record?
      rescue => e
        @errors << "Previsão — linha #{line} (CR #{cr_code.presence || '?'}): #{e.message}"
      end
    end

    def parse_excel_date(raw)
      return nil if raw.blank?
      return raw if raw.is_a?(Date)

      numeric = raw.to_f
      return nil if numeric == 0

      Date.new(1899, 12, 30) + numeric.to_i
    rescue
      nil
    end
  end
end
