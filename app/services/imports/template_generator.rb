require "caxlsx"

module Imports
  class TemplateGenerator
    PT_MONTHS = %w[JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO].freeze

    def call
      package = Axlsx::Package.new
      wb = package.workbook

      add_cost_centers_sheet(wb)
      add_invoices_sheet(wb)
      add_receipts_sheet(wb)
      add_forecasts_sheet(wb)

      package.to_stream.read
    end

    private

    def add_cost_centers_sheet(wb)
      wb.add_worksheet(name: "CADASTRO CENTRO DE CUSTO") do |sheet|
        # Importer skips rows 1-4 (offset: 4); data starts at row 5
        sheet.add_row ["CADASTRO CENTRO DE CUSTO"]
        sheet.add_row []
        sheet.add_row []
        sheet.add_row ["ORD", "CR", "PART.% UFC", "DESCRIÇÃO", "CLIENTE", "OBJETO", "COORDENADOR"]
        sheet.add_row [1, "4452", 1.0, "FISC SEAP ARQ BA", "SEAP", "Descrição do objeto contratual", "Nome do Coordenador"]
      end
    end

    def add_invoices_sheet(wb)
      wb.add_worksheet(name: "FATURAMENTO") do |sheet|
        # Importer skips rows 1-5 (offset: 5); data starts at row 6
        sheet.add_row ["FATURAMENTO"]
        sheet.add_row []
        sheet.add_row []
        sheet.add_row []
        sheet.add_row ["SEQ", "CENTRO DE CUSTO", "NF", "CR", "CLIENTE", "DATA EMISSÃO", "VALOR", "MÊS EMISSÃO", "OBSERVAÇÃO"]
        sheet.add_row [1, "Centro de Custo Exemplo", "12345", "4452", "NOME DO CLIENTE", Date.current, 50_000.00, current_month_year, ""]
      end
    end

    def add_receipts_sheet(wb)
      wb.add_worksheet(name: "RECEBIMENTO") do |sheet|
        # Importer skips rows 1-5 (offset: 5); data starts at row 6
        sheet.add_row ["RECEBIMENTO"]
        sheet.add_row []
        sheet.add_row []
        sheet.add_row []
        sheet.add_row ["SEQ", "NF", "CR", "CLIENTE", "DATA BAIXA", "RECEBIDO NO MÊS", "MÊS BAIXA"]
        sheet.add_row [1, "12345", "4452", "NOME DO CLIENTE", Date.current, 50_000.00, current_month_year]
      end
    end

    def add_forecasts_sheet(wb)
      month_year = current_month_year

      wb.add_worksheet(name: "PREVISAO FATURAMENTO") do |sheet|
        # cell(3, 9) = I3 = month_year; importer skips rows 1-5 (offset: 5)
        sheet.add_row ["PREVISAO FATURAMENTO"]
        sheet.add_row []
        sheet.add_row ["", "", "", "", "", "", "", "", month_year]  # I3 = month_year
        sheet.add_row []
        sheet.add_row ["ORD", "CR", "PART.%", "OBJETO", "DESCRIÇÃO", "CLIENTE", "DATA FINAL", "COORDENADOR", "", "PREVISTO TOTAL", "% UFC", "REALIZADO TOTAL", "% UFC REAL."]
        sheet.add_row [1, "4452", 1.0, "Descrição do objeto", "FISC SEAP ARQ BA", "SEAP", Date.current, "Nome Coordenador", "", 100_000.00, 1.0, 80_000.00, 1.0]
      end
    end

    def current_month_year
      "#{PT_MONTHS[Date.current.month - 1]}/#{Date.current.year}"
    end
  end
end
