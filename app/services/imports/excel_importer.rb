require "roo"

module Imports
  class ExcelImporter
    Result = Struct.new(:success?, :errors, keyword_init: true)

    SHEETS = {
      cost_centers: "CADASTRO CENTRO DE CUSTO",
      invoices:     "FATURAMENTO",
      receipts:     "RECEBIMENTO",
      forecasts:    "PREVISAO FATURAMENTO"
    }.freeze

    def initialize(file_path)
      @file_path = file_path
      @errors = []
    end

    def call
      workbook = Roo::Spreadsheet.open(@file_path.to_s)
      import_cost_centers(workbook)
      import_invoices(workbook)
      import_receipts(workbook)
      import_forecasts(workbook)
      Result.new(success?: @errors.empty?, errors: @errors)
    rescue => e
      Result.new(success?: false, errors: ["Erro ao processar arquivo: #{e.message}"])
    end

    private

    def import_cost_centers(wb)
      sheet = wb.sheet(SHEETS[:cost_centers])
      sheet.each_row_streaming(offset: 4, pad_cells: true) do |row|
        next if row[0].nil? || row[0].value.blank?

        cr_code = row[1]&.value&.to_s&.strip
        next if cr_code.blank?

        client_name = row[4]&.value&.to_s&.strip
        next if client_name.blank?

        client = Client.find_or_create_by!(name: client_name) do |c|
          c.full_name = client_name
        end

        CostCenter.find_or_create_by!(cr_code: cr_code) do |cc|
          cc.description  = row[3]&.value&.to_s&.strip || ""
          cc.participation = row[2]&.value.to_f || 1.0
          cc.coordinator   = row[6]&.value&.to_s&.strip || ""
          cc.client        = client
        end
      rescue => e
        @errors << "Centro de custo #{cr_code}: #{e.message}"
      end
    end

    def import_invoices(wb)
      sheet = wb.sheet(SHEETS[:invoices])
      sheet.each_row_streaming(offset: 5, pad_cells: true) do |row|
        cr_code = row[3]&.value&.to_s&.strip
        nf_number = row[2]&.value&.to_s&.strip
        next if cr_code.blank? || nf_number.blank?

        cost_center = CostCenter.find_by(cr_code: cr_code)
        next if cost_center.nil?

        raw_date = row[5]&.value
        issued_at = parse_excel_date(raw_date)
        next if issued_at.nil?

        Invoice.find_or_create_by!(cost_center: cost_center, number: nf_number) do |inv|
          inv.client_name = row[4]&.value&.to_s&.strip || ""
          inv.issued_at   = issued_at
          inv.value       = row[6]&.value.to_f
        end
      rescue => e
        @errors << "Nota fiscal #{nf_number}: #{e.message}"
      end
    end

    def import_receipts(wb)
      sheet = wb.sheet(SHEETS[:receipts])
      sheet.each_row_streaming(offset: 5, pad_cells: true) do |row|
        nf_number   = row[1]&.value&.to_s&.strip
        cr_code     = row[2]&.value&.to_s&.strip
        next if nf_number.blank? || cr_code.blank?

        cost_center = CostCenter.find_by(cr_code: cr_code)
        invoice     = Invoice.find_by(cost_center: cost_center, number: nf_number)
        next if invoice.nil?

        raw_date = row[4]&.value
        payment_date = parse_excel_date(raw_date)
        next if payment_date.nil?

        receipt_value = row[5]&.value.to_f
        next if receipt_value <= 0

        Receipt.create!(invoice: invoice, payment_date: payment_date, value: receipt_value)
      rescue => e
        @errors << "Recebimento NF #{nf_number}: #{e.message}"
      end
    end

    def import_forecasts(wb)
      sheet = wb.sheet(SHEETS[:forecasts])
      sheet.each_row_streaming(offset: 5, pad_cells: true) do |row|
        cr_code = row[1]&.value&.to_s&.strip
        next if cr_code.blank?

        cost_center = CostCenter.find_by(cr_code: cr_code)
        next if cost_center.nil?

        month_year = sheet.cell(3, 9).to_s.strip

        ForecastEntry.find_or_create_by!(cost_center: cost_center, month_year: month_year) do |fe|
          fe.forecasted_total    = row[9]&.value.to_f
          fe.forecasted_pct_ufc  = row[10]&.value.to_f
          fe.realized_total      = row[11]&.value.to_f
          fe.realized_pct_ufc    = row[12]&.value.to_f
        end
      rescue => e
        @errors << "Previsão #{cr_code}: #{e.message}"
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
