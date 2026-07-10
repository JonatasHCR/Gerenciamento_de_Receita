require "prawn"
require "prawn/table"

module CostCenters
  # PDF da "Relação de Compromissos - MOD". Traz as colunas principais (o detalhamento
  # UFC — % UFC, totais e valores UFC — fica só no Excel). Espelha o estilo dos demais
  # PDFs (fonte AFM/WinAnsi + safe()). SALDO usa o valor UFC (participação aplicada).
  class CommitmentsPdf
    Prawn::Fonts::AFM.hide_m17n_warning = true

    RED       = "B91C1C".freeze
    DARK_RED  = "7F1D1D".freeze
    GRAY_HEAD = "F3F4F6".freeze
    GRAY_LINE = "E5E7EB".freeze
    MUTED     = "6B7280".freeze

    COLUMNS = ["Nº CONTRATO", "CONTRATANTE", "CENTRO DE RESULTADO", "OBJETO",
               "INÍCIO", "FIM", "VALOR", "% A EXEC.", "SALDO"].freeze
    WIDTHS  = [72, 112, 80, 182, 52, 52, 78, 52, 78].freeze

    def initialize(cost_centers, generated_by: nil)
      @cost_centers = cost_centers
      @generated_by = generated_by
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: [40, 36, 50, 36])
      header
      if @cost_centers.empty?
        @pdf.move_down 30
        @pdf.text "Nenhum centro de custo para exibir.", size: 11, color: MUTED, align: :center
      else
        table
      end
      footer
      @pdf.render
    end

    private

    def header
      @pdf.fill_color RED
      @pdf.text "UFC Engenharia", size: 18, style: :bold
      @pdf.fill_color "000000"
      @pdf.text "Relação de Compromissos - MOD", size: 13, style: :bold
      @pdf.fill_color MUTED
      @pdf.text "Emitido em #{I18n.l(Date.current)}", size: 10
      @pdf.fill_color "000000"
      @pdf.stroke_color GRAY_LINE
      @pdf.stroke_horizontal_rule
      @pdf.move_down 10
    end

    def table
      # Faturado PRINCIPAL por CC numa única query (evita N+1 de saldo/%).
      principal = Invoice.principal.where(cost_center_id: @cost_centers.map(&:id))
                         .group(:cost_center_id).sum(:value)

      rows = [COLUMNS]
      total_valor = total_saldo = 0
      @cost_centers.each do |cc|
        valor     = cc.value.to_f
        saldo     = valor - (principal[cc.id] || 0).to_f
        pct       = valor.zero? ? 0 : (saldo / valor * 100).round(2)
        saldo_ufc = saldo * cc.participation.to_f
        total_valor += valor
        total_saldo += saldo_ufc

        rows << [
          safe(cc.contract_number.to_s), safe(cc.client&.name.to_s), safe(cc.cr_code.to_s),
          safe(cc.object_text.to_s), fmt_date(cc.start_date), fmt_date(cc.end_date),
          brl(valor), pct_fmt(pct), brl(saldo_ufc)
        ]
      end
      rows << ["", "", "", "", "", "TOTAL", brl(total_valor), "", brl(total_saldo)]
      total_row = rows.size - 1

      @pdf.table(rows, column_widths: WIDTHS, cell_style: { size: 7, padding: [3, 4] }) do |t|
        [6, 8].each { |c| t.column(c).align = :right }
        [4, 5, 7].each { |c| t.column(c).align = :center }

        t.row(0).background_color = GRAY_HEAD
        t.row(0).font_style       = :bold
        t.row(0).text_color       = MUTED
        t.row(0).align            = :center

        t.row(total_row).background_color = GRAY_HEAD
        t.row(total_row).font_style       = :bold

        t.cells.borders      = [:bottom]
        t.cells.border_color = GRAY_LINE
        t.row(0).borders     = [:top, :bottom]
      end
    end

    def footer
      @pdf.number_pages "Página <page> de <total>",
                        at: [0, -10], align: :right, size: 7, color: MUTED
      @pdf.repeat(:all) do
        @pdf.fill_color MUTED
        meta = "Gerado em #{I18n.l(Time.current, format: :short)}"
        meta += " por #{@generated_by}" if @generated_by.present?
        @pdf.draw_text safe(meta), at: [0, -10], size: 7
        @pdf.fill_color "000000"
      end
    end

    def brl(value)
      ActiveSupport::NumberHelper.number_to_currency(
        value || 0, unit: "R$ ", separator: ",", delimiter: ".", precision: 2
      )
    end

    def pct_fmt(value)
      format("%.2f%%", value).tr(".", ",")
    end

    def fmt_date(date)
      date&.strftime("%d/%m/%Y") || ""
    end

    def safe(text)
      text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
          .encode("UTF-8")
    end
  end
end
