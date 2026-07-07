require "prawn"
require "prawn/table"

module Reports
  # PDF da "Relação das Faturas em Aberto", por cliente → centro de custo.
  # Colunas: CLIENTE, NF, DT EMISSÃO, CC, CONTRATO, VALOR (saldo em aberto).
  # Espelha o estilo do MonthlyReportPdf (fonte AFM/WinAnsi + safe()).
  class OpenInvoicesPdf
    Prawn::Fonts::AFM.hide_m17n_warning = true

    RED         = "B91C1C".freeze
    DARK_RED    = "7F1D1D".freeze
    GRAY_HEAD   = "F3F4F6".freeze
    GRAY_LINE   = "E5E7EB".freeze
    MUTED       = "6B7280".freeze
    PARTIAL_BG  = "FEF3C7".freeze  # amber-100 — NF parcialmente paga
    PARTIAL_DOT = "F59E0B".freeze  # amber-500 — swatch da legenda

    COLUMNS = ["CLIENTE", "NF", "DT EMISSÃO", "CC", "CONTRATO", "VALOR"].freeze

    def initialize(report_data:, generated_by: nil)
      @data         = report_data
      @generated_by = generated_by
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", page_layout: :portrait, margin: [40, 36, 50, 36])

      header
      if @data.empty?
        @pdf.move_down 30
        @pdf.text "Nenhuma fatura em aberto para a seleção.", size: 11, color: MUTED, align: :center
      else
        @data.each_with_index do |group, i|
          @pdf.start_new_page if i.positive?
          client_section(group)
        end
        grand_total if @data.size > 1
      end
      footer

      @pdf.render
    end

    private

    def header
      @pdf.fill_color RED
      @pdf.text "UFC Engenharia", size: 18, style: :bold
      @pdf.fill_color "000000"
      @pdf.text "Relação das Faturas em Aberto", size: 13, style: :bold
      @pdf.fill_color MUTED
      @pdf.text "Emitido em #{I18n.l(Date.current)}", size: 10
      @pdf.fill_color "000000"
      @pdf.stroke_color GRAY_LINE
      @pdf.stroke_horizontal_rule
      @pdf.move_down 10

      # Legenda: swatch (retângulo) + texto — sem glifos fora do WinAnsi.
      y = @pdf.cursor
      @pdf.fill_color PARTIAL_BG
      @pdf.fill_rectangle [0, y], 16, 9
      @pdf.stroke_color PARTIAL_DOT
      @pdf.stroke_rectangle [0, y], 16, 9
      @pdf.fill_color MUTED
      @pdf.draw_text safe("= fatura parcialmente paga (já teve recebimento). VALOR = saldo em aberto."),
                     at: [22, y - 7], size: 8
      @pdf.fill_color "000000"
      @pdf.move_down 14
    end

    def client_section(group)
      client = group[:client]

      @pdf.move_down 4
      @pdf.fill_color DARK_RED
      @pdf.text(safe(client&.name || "Sem Cliente"), size: 12, style: :bold)
      @pdf.fill_color "000000"
      @pdf.move_down 4

      table_data = [COLUMNS]
      subtotal_rows = []
      partial_rows  = []

      group[:cost_centers].each do |cc_group|
        cc = cc_group[:cc]
        cc_group[:invoices].each do |inv|
          table_data << [
            safe(client&.name.to_s), safe(inv.number.to_s), fmt_date(inv.issued_at),
            safe(cc.cr_code.to_s), safe(cc.contract_number.to_s), brl(inv.balance)
          ]
          partial_rows << table_data.size - 1 if inv.partially_paid?
        end
        table_data << ["", "", "", safe(cc.cr_code.to_s), "Subtotal", brl(cc_group[:subtotal])]
        subtotal_rows << table_data.size - 1
      end

      table_data << ["", "", "", "", "TOTAL #{safe(client&.name.to_s)}", brl(group[:total])]
      total_row = table_data.size - 1

      @pdf.table(table_data, width: @pdf.bounds.width, cell_style: { size: 8, padding: [4, 5] }) do |t|
        t.column(5).align = :right
        t.column(2).align = :center
        t.column(3).align = :center

        t.row(0).background_color = GRAY_HEAD
        t.row(0).font_style       = :bold
        t.row(0).text_color       = MUTED
        t.row(0).align            = :center

        partial_rows.each { |r| t.row(r).background_color = PARTIAL_BG }
        subtotal_rows.each do |r|
          t.row(r).background_color = "EFF6FF"
          t.row(r).font_style       = :bold
        end
        t.row(total_row).background_color = GRAY_HEAD
        t.row(total_row).font_style       = :bold

        t.cells.borders      = [:bottom]
        t.cells.border_color = GRAY_LINE
        t.row(0).borders     = [:top, :bottom]
      end

      @pdf.move_down 10
    end

    def grand_total
      total = @data.sum { |g| g[:total] }
      @pdf.move_down 6
      row = [["TOTAL GERAL", brl(total)]]
      @pdf.table(row, width: @pdf.bounds.width, cell_style: { size: 10, padding: [6, 5] }) do |t|
        t.column(1).align = :right
        t.column(0).width = @pdf.bounds.width - 130
        t.cells.background_color = DARK_RED
        t.cells.text_color       = "FFFFFF"
        t.cells.font_style       = :bold
        t.cells.borders          = []
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

    def fmt_date(date)
      date&.strftime("%d/%m/%Y") || ""
    end

    def safe(text)
      text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
          .encode("UTF-8")
    end
  end
end
