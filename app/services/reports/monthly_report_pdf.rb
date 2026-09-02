require "prawn"
require "prawn/table"

module Reports
  # Gera o PDF do relatório mensal a partir da árvore de MonthlyReportQuery.
  # As seções fluem na página — não há quebra forçada por grupo.
  class MonthlyReportPdf
    include PdfStyling
    Prawn::Fonts::AFM.hide_m17n_warning = true

    def initialize(report_data:, period_label:, ranged: false, filter_label: nil, generated_by: nil)
      @data         = report_data
      @month_label  = period_label
      @ranged       = ranged
      @filter_label = filter_label
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

      document_header(@pdf, "Relatório Mensal de Receitas",
                      ["Período: #{@month_label}", @filter_label])

      if @data[:totals][:count].zero?
        @pdf.move_down 30
        @pdf.text "Nenhum dado encontrado para o período.", size: 11, color: MUTED, align: :center
      else
        @data[:groups].each { |node| render_node(node, 1) }
        grand_total
      end

      page_footer(@pdf, @generated_by)
      @pdf.render
    end

    private

    def render_node(node, depth)
      ensure_space(@pdf, 90)
      draw_group_header(node, depth) if node[:label].present?

      if node[:children].any?
        node[:children].each { |child| render_node(child, depth + 1) }
        # Nível com um único filho repete o subtotal que o filho já imprimiu.
        subtotal_row(node, depth) if node[:children].size > 1
      else
        rows_table(node)
      end
    end

    def draw_group_header(node, depth)
      @pdf.move_down depth == 1 ? 8 : 5
      size, color = depth == 1 ? [11, DARK_RED] : [10, RED]
      @pdf.fill_color color
      @pdf.text safe(node[:label].to_s), size: size, style: :bold
      @pdf.fill_color "000000"
      @pdf.move_down 4
    end

    # Tabela do nível folha, já com a linha de subtotal do próprio grupo.
    def rows_table(node)
      table_data = [columns]

      node[:rows].each do |r|
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

      totals = node[:totals]
      table_data << [
        "", "", safe("Subtotal #{node[:label]}"),
        brl(totals[:previsto]), brl(totals[:inv_cur]), brl(totals[:open_pre]),
        brl(totals[:rec_cur]), brl(totals[:open])
      ]

      @pdf.table(table_data, width: @pdf.bounds.width, header: true,
                 cell_style: { size: 8, padding: [4, 5] }) do |t|
        t.columns(3..7).align = :right
        t.column(1).align = :center
        t.column(0).width = 45
        t.column(1).width = 50
        t.column(2).width = 150

        t.row(0).background_color = GRAY_HEAD
        t.row(0).font_style       = :bold
        t.row(0).text_color       = MUTED
        t.row(0).align            = :center

        last = table_data.size - 1
        t.row(last).background_color = GRAY_SUB
        t.row(last).font_style       = :bold

        t.cells.borders      = [:bottom]
        t.cells.border_color = GRAY_LINE
        t.row(0).borders     = [:top, :bottom]
      end

      @pdf.move_down 8
    end

    # Subtotal de um nível intermediário (ex.: coordenador agrupando clientes).
    def subtotal_row(node, depth)
      totals = node[:totals]
      row = [[
        safe("Subtotal #{node[:label]}"), brl(totals[:previsto]), brl(totals[:inv_cur]),
        brl(totals[:open_pre]), brl(totals[:rec_cur]), brl(totals[:open])
      ]]

      ensure_space(@pdf, 40)
      @pdf.table(row, width: @pdf.bounds.width, cell_style: { size: 8, padding: [4, 5] }) do |t|
        t.columns(1..5).align = :right
        t.column(0).width = 245
        t.cells.background_color = depth == 1 ? GRAY_HEAD : GRAY_SUB
        t.cells.font_style       = :bold
        t.cells.borders          = []
      end
      @pdf.move_down 8
    end

    # Total geral vem da RAIZ da árvore (linhas planas), então um CC com vários
    # coordenadores não é contado duas vezes.
    def grand_total
      g = @data[:totals]

      ensure_space(@pdf, 40)
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
  end
end
