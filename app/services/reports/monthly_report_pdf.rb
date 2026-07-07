require "prawn"
require "prawn/table"

module Reports
  # Gera o PDF do relatório mensal a partir dos dados de MonthlyReportQuery.
  #
  # Usa a fonte AFM Helvetica embutida (encoding WinAnsi/CP1252), que cobre
  # todos os acentos do português. Texto é sanitizado para WinAnsi para
  # evitar erro caso surja algum caractere fora do conjunto (ex: emoji).
  class MonthlyReportPdf
    Prawn::Fonts::AFM.hide_m17n_warning = true

    RED        = "B91C1C".freeze
    DARK_RED   = "7F1D1D".freeze
    GRAY_HEAD  = "F3F4F6".freeze
    GRAY_LINE  = "E5E7EB".freeze
    GREEN      = "15803D".freeze
    MUTED      = "6B7280".freeze

    def initialize(report_data:, period_label:, ranged: false, generated_by: nil)
      @data         = report_data
      @month_label  = period_label
      @ranged       = ranged
      @generated_by = generated_by
    end

    def columns
      suffix = @ranged ? "no Período" : "no Mês"
      ["CR", "Part. UFC", "Descrição", "Previsto #{suffix}", "Faturado #{suffix}",
       @ranged ? "Em Aberto Anterior" : "Em Aberto Mês Ant.",
       "Recebido #{suffix}", "Faturas em Aberto"]
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: [40, 36, 50, 36])

      header
      if @data.empty?
        @pdf.move_down 30
        @pdf.text "Nenhum dado encontrado para o período.", size: 11, color: MUTED, align: :center
      else
        @data.each { |group| client_section(group) }
        grand_total
      end
      footer

      @pdf.render
    end

    private

    def header
      @pdf.fill_color RED
      @pdf.text "UFC Engenharia", size: 18, style: :bold
      @pdf.fill_color "000000"
      @pdf.text "Relatório Mensal de Receitas", size: 13, style: :bold
      @pdf.fill_color MUTED
      @pdf.text "Período: #{@month_label}", size: 10
      @pdf.fill_color "000000"
      @pdf.stroke_color GRAY_LINE
      @pdf.stroke_horizontal_rule
      @pdf.move_down 14
    end

    def client_section(group)
      client = group[:client]
      rows   = group[:cost_centers]
      totals = group[:totals]

      @pdf.move_down 6
      @pdf.fill_color DARK_RED
      @pdf.text(safe(client&.name || "Sem Cliente"), size: 11, style: :bold)
      @pdf.fill_color "000000"
      @pdf.move_down 4

      table_data = [columns]

      rows.each do |r|
        table_data << [
          safe(r[:cc].cr_code.to_s),
          pct(r[:cc].participation),
          safe(truncate(r[:cc].description, 36)),
          brl(r[:previsto]),
          brl(r[:inv_cur]),
          brl(r[:open_pre]),
          brl(r[:rec_cur]),
          brl(r[:open])
        ]
      end

      table_data << [
        "", "", safe("Subtotal #{client&.name}"),
        brl(totals[:previsto]), brl(totals[:inv_cur]), brl(totals[:open_pre]),
        brl(totals[:rec_cur]), brl(totals[:open])
      ]

      @pdf.table(table_data, width: @pdf.bounds.width, cell_style: { size: 8, padding: [4, 5] }) do |t|
        t.columns(3..7).align = :right
        t.column(1).align = :center
        t.column(0).width = 45
        t.column(1).width = 50
        t.column(2).width = 150

        # Cabeçalho
        t.row(0).background_color = GRAY_HEAD
        t.row(0).font_style       = :bold
        t.row(0).text_color       = MUTED
        t.row(0).align            = :center

        # Linha de subtotal
        last = table_data.size - 1
        t.row(last).background_color = GRAY_HEAD
        t.row(last).font_style       = :bold

        t.cells.borders            = [:bottom]
        t.cells.border_color       = GRAY_LINE
        t.row(0).borders           = [:top, :bottom]
      end

      @pdf.move_down 10
    end

    def grand_total
      g = {
        previsto: @data.sum { |grp| grp[:totals][:previsto] },
        inv_cur:  @data.sum { |grp| grp[:totals][:inv_cur] },
        open_pre: @data.sum { |grp| grp[:totals][:open_pre] },
        rec_cur:  @data.sum { |grp| grp[:totals][:rec_cur] },
        open:     @data.sum { |grp| grp[:totals][:open] }
      }

      @pdf.move_down 4
      total_row = [[
        "TOTAL GERAL", brl(g[:previsto]), brl(g[:inv_cur]),
        brl(g[:open_pre]), brl(g[:rec_cur]), brl(g[:open])
      ]]

      @pdf.table(total_row, width: @pdf.bounds.width, cell_style: { size: 9, padding: [6, 5] }) do |t|
        t.columns(1..5).align = :right
        t.column(0).width = 245
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

    # Participação (decimal 0..1) → percentual: 1.0 → "100%", 0.5 → "50%"
    def pct(value)
      return "—" if value.nil?
      n = value * 100
      n = n == n.to_i ? n.to_i : n.round(2)
      "#{n.to_s.tr('.', ',')}%"
    end

    def truncate(text, length)
      return "" if text.blank?
      text.length > length ? "#{text[0, length - 1]}…" : text
    end

    # Garante que o texto é compatível com a fonte AFM (WinAnsi/CP1252),
    # substituindo qualquer caractere fora do conjunto por "?".
    def safe(text)
      text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
          .encode("UTF-8")
    end
  end
end
