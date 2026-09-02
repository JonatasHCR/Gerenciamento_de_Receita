require "prawn"
require "prawn/table"

module CostCenters
  # PDF da "Relação de Compromissos - MOD". Traz as colunas principais (o detalhamento
  # UFC — % UFC, totais e valores UFC — fica só no Excel). Espelha o estilo dos demais
  # PDFs (fonte AFM/WinAnsi + safe()). SALDO usa o valor UFC (participação aplicada).
  #
  # `levels:` vem do Reports::ScopeFilter#levels(row_is_cost_center: true).
  # Vazio (padrão) = lista plana, idêntica ao comportamento anterior.
  class CommitmentsPdf
    include Reports::PdfStyling
    Prawn::Fonts::AFM.hide_m17n_warning = true

    COLUMNS = ["Nº CONTRATO", "CONTRATANTE", "CENTRO DE RESULTADO", "OBJETO",
               "INÍCIO", "FIM", "VALOR", "% A EXEC.", "SALDO"].freeze
    WIDTHS  = [72, 112, 80, 182, 52, 52, 78, 52, 78].freeze

    def initialize(cost_centers, levels: [], filter_label: nil, generated_by: nil)
      @cost_centers = cost_centers
      @levels       = Array(levels)
      @filter_label = filter_label
      @generated_by = generated_by
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: [40, 36, 50, 36])
      document_header(@pdf, "Relação de Compromissos - MOD",
                      ["Emitido em #{I18n.l(Date.current)}", @filter_label])

      if @cost_centers.empty?
        @pdf.move_down 30
        @pdf.text "Nenhum centro de custo para exibir.", size: 11, color: MUTED, align: :center
      else
        tree[:groups].each { |node| render_node(node, 1) }
        grand_total if @levels.any?
      end

      page_footer(@pdf, @generated_by)
      @pdf.render
    end

    private

    def tree
      @tree ||= Reports::GroupTree.build(rows, levels: @levels, sum_keys: %i[valor saldo_ufc])
    end

    # Faturado PRINCIPAL por CC numa única query (evita N+1 de saldo/%).
    def rows
      @rows ||= begin
        principal = Invoice.principal.where(cost_center_id: @cost_centers.map(&:id))
                           .group(:cost_center_id).sum(:value)

        @cost_centers.map do |cc|
          valor = cc.value.to_f
          saldo = valor - (principal[cc.id] || 0).to_f
          { cc: cc, client: cc.client, valor: valor, saldo: saldo,
            pct: valor.zero? ? 0 : (saldo / valor * 100).round(2),
            saldo_ufc: saldo * cc.participation.to_f }
        end
      end
    end

    def render_node(node, depth)
      ensure_space(@pdf, 90)

      if node[:label].present?
        @pdf.move_down depth == 1 ? 8 : 5
        @pdf.fill_color depth == 1 ? DARK_RED : RED
        @pdf.text safe(node[:label].to_s), size: depth == 1 ? 11 : 10, style: :bold
        @pdf.fill_color "000000"
        @pdf.move_down 4
      end

      if node[:children].any?
        node[:children].each { |child| render_node(child, depth + 1) }
        # Nível com um único filho repete o subtotal que o filho já imprimiu.
        subtotal_bar(node, depth) if node[:children].size > 1
      else
        table(node)
      end
    end

    def table(node)
      rows = [COLUMNS]
      node[:rows].each do |r|
        cc = r[:cc]
        rows << [
          safe(cc.contract_number.to_s), safe(cc.client&.name.to_s), safe(cc.cr_code.to_s),
          safe(cc.object_text.to_s), fmt_date(cc.start_date), fmt_date(cc.end_date),
          brl(r[:valor]), pct_fmt(r[:pct]), brl(r[:saldo_ufc])
        ]
      end

      totals = node[:totals]
      label  = node[:label].present? ? "Subtotal" : "TOTAL"
      rows << ["", "", "", "", "", label, brl(totals[:valor]), "", brl(totals[:saldo_ufc])]
      total_row = rows.size - 1

      @pdf.table(rows, column_widths: WIDTHS, header: true, cell_style: { size: 7, padding: [3, 4] }) do |t|
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
      @pdf.move_down 6
    end

    def subtotal_bar(node, depth)
      bar(safe("Subtotal #{node[:label]}"), node[:totals],
          bg: depth == 1 ? GRAY_HEAD : GRAY_SUB, size: 8)
    end

    # Total geral vem da RAIZ (linhas planas): CC com vários coordenadores não
    # é contado duas vezes.
    def grand_total
      @pdf.move_down 4
      bar("TOTAL GERAL", tree[:totals], bg: DARK_RED, size: 9, fg: "FFFFFF")
    end

    def bar(label, totals, bg:, size:, fg: nil)
      ensure_space(@pdf, 40)
      row = [[label, brl(totals[:valor]), brl(totals[:saldo_ufc])]]
      @pdf.table(row, column_widths: [WIDTHS.sum - 156, 78, 78], cell_style: { size: size, padding: [4, 5] }) do |t|
        t.columns(1..2).align = :right
        t.cells.background_color = bg
        t.cells.text_color       = fg if fg
        t.cells.font_style       = :bold
        t.cells.borders          = []
      end
      @pdf.move_down 6
    end

    def pct_fmt(value)
      format("%.2f%%", value).tr(".", ",")
    end
  end
end
