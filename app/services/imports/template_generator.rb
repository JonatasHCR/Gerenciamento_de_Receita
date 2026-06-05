require "caxlsx"

module Imports
  # Gera o modelo .xlsx de importação. O ExcelImporter detecta colunas pelo
  # CABEÇALHO, então a ordem é flexível — aqui usamos um layout limpo, sem
  # colunas redundantes (a data já indica o mês; CR identifica o centro de custo).
  # Participação é informada em PERCENTUAL (0 a 100).
  class TemplateGenerator
    PT_MONTHS = %w[JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO].freeze

    def call
      package = Axlsx::Package.new
      wb = package.workbook

      add_cost_centers_sheet(wb)
      add_forecasts_sheet(wb)
      add_invoices_sheet(wb)
      add_receipts_sheet(wb)

      package.to_stream.read
    end

    private

    def add_cost_centers_sheet(wb)
      wb.add_worksheet(name: "CADASTRO CENTRO DE CUSTO") do |sheet|
        sheet.add_row ["CADASTRO CENTRO DE CUSTO"]
        sheet.add_row []
        sheet.add_row []
        sheet.add_row ["CR", "PART. (%)", "DESCRIÇÃO", "CLIENTE", "Nº CONTRATO",
                       "OBJETO", "INÍCIO", "DATA FINAL", "VALOR", "COORDENADOR"]
        sheet.add_row ["4452", 100, "FISC SEAP ARQ BA", "SEAP", "055/2025",
                       "Objeto do contrato", Date.current, Date.current.next_year,
                       500_000.00, "Coordenador A / Gestor B"]
      end
    end

    # PREVISÃO enxuta: CR, Mês/Ano (numérico), Previsto, Observação.
    # (Objeto/Data Final/Coordenador ficam no CADASTRO; Realizado é derivado do faturamento.)
    def add_forecasts_sheet(wb)
      wb.add_worksheet(name: "PREVISAO FATURAMENTO") do |sheet|
        sheet.add_row ["PREVISAO FATURAMENTO"]
        sheet.add_row []
        sheet.add_row []
        sheet.add_row ["CR", "MÊS/ANO", "PREVISTO", "OBSERVAÇÃO"]
        sheet.add_row ["4452", current_month_numeric, 270_000.0, ""]
      end
    end

    def add_invoices_sheet(wb)
      wb.add_worksheet(name: "FATURAMENTO") do |sheet|
        sheet.add_row ["FATURAMENTO"]
        sheet.add_row []
        sheet.add_row []
        # Cliente sai (vem do CR); TIPO = PRINCIPAL ou REAJUSTE (padrão PRINCIPAL).
        sheet.add_row ["NOTA FISCAL", "CR", "DATA EMISSÃO", "VALOR", "TIPO", "OBSERVAÇÃO"]
        sheet.add_row ["12345", "4452", Date.current, 50_000.00, "PRINCIPAL", ""]
      end
    end

    def add_receipts_sheet(wb)
      wb.add_worksheet(name: "RECEBIMENTO") do |sheet|
        sheet.add_row ["RECEBIMENTO"]
        sheet.add_row []
        sheet.add_row []
        # Cliente sai (vem do CR); "VALOR" no lugar de "RECEBIDO NO MÊS".
        sheet.add_row ["NOTA FISCAL", "CR", "DATA BAIXA", "VALOR", "OBSERVAÇÃO"]
        sheet.add_row ["12345", "4452", Date.current, 50_000.00, ""]
      end
    end

    def current_month_year
      "#{PT_MONTHS[Date.current.month - 1]}/#{Date.current.year}"
    end

    def current_month_numeric
      format("%02d/%d", Date.current.month, Date.current.year)
    end
  end
end
