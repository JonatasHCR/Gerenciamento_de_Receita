require "prawn"
require "prawn/table"

module Reports
  # PDF do Relatório de Movimentação (faturamento / recebimento / ambos).
  # Renderiza a árvore do Reports::GroupTree recursivamente. Dentro de cada
  # centro de custo (nível folha) a seção pode ter mais de um BLOCO — ver
  # Reports::MovementReportQuery. As seções FLUEM na página: não há quebra por
  # grupo, só o cuidado de não deixar cabeçalho órfão no pé da folha.
  class MovementPdf
    include PdfStyling
    Prawn::Fonts::AFM.hide_m17n_warning = true

    HEADERS = {
      number:          "NF",
      issued_at:       "DT EMISSÃO",
      last_payment:    "DT BAIXA",
      payment_date:    "DT BAIXA",
      cr_code:         "CC",
      contract_number: "CONTRATO",
      value:           "VALOR",
      received:        "RECEBIDO",
      balance:         "EM ABERTO"
    }.freeze

    NUMERIC  = %i[value received balance].freeze
    CENTERED = %i[issued_at last_payment payment_date cr_code].freeze

    def initialize(report_data:, filter_label: nil, period_label: nil, generated_by: nil)
      @data         = report_data
      @filter_label = filter_label
      @period_label = period_label
      @generated_by = generated_by
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", page_layout: :portrait, margin: [40, 36, 50, 36])

      document_header(@pdf, "Relatório de Movimentação", header_lines)
      legend if flagged?

      @data[:sections].each_with_index do |section, i|
        @pdf.move_down 8 if i.positive?
        render_section(section)
      end
      grand_summary

      page_footer(@pdf, @generated_by)
      @pdf.render
    end

    private

    # Legenda só quando algum bloco realmente sinaliza linhas.
    def flagged? = %i[partial open].any? { |flag| flag_used?(flag) }

    def flag_used?(flag)
      @data[:sections].any? { |s| Array(s[:blocks]).any? { |b| Array(b[:flags]).include?(flag) } }
    end

    def header_lines
      [
        "Tipo: #{tipo_label}#{@data[:only_open] ? ' (somente faturas em aberto)' : ''}",
        @period_label.presence || "Período: todos os lançamentos",
        @filter_label
      ]
    end

    def tipo_label
      { faturamento: "Faturamento", recebimento: "Recebimento", ambos: "Faturamento e Recebimento" }
        .fetch(@data[:tipo], "Faturamento e Recebimento")
    end

    def legend
      legend_swatch(@pdf, PARTIAL_BG, PARTIAL_DOT, "= recebida em parte.") if flag_used?(:partial)
      legend_swatch(@pdf, OPEN_BG, OPEN_DOT, "= sem nenhum recebimento.")  if flag_used?(:open)
      if @data[:period_end].present?
        @pdf.fill_color MUTED
        @pdf.text safe("Situação apurada em #{fmt_date(@data[:period_end])}: baixa posterior a essa data não é considerada."),
                  size: 8
        @pdf.fill_color "000000"
        @pdf.move_down 4
      end
    end

    # --- Seções e grupos -----------------------------------------------------

    def render_section(section)
      ensure_space(@pdf, 90)
      @pdf.fill_color RED
      @pdf.text safe(section[:title].upcase), size: 12, style: :bold
      @pdf.fill_color "000000"
      @pdf.move_down 6

      if section[:tree][:totals][:count].zero?
        @pdf.text "Nenhum lançamento para a seleção.", size: 10, color: MUTED, align: :center
        @pdf.move_down 6
        return
      end

      section[:tree][:groups].each { |node| render_node(section, node, 1) }

      if section[:truncated]
        @pdf.fill_color MUTED
        @pdf.text safe("Resultado truncado — refine o período ou os filtros."), size: 8, style: :italic
        @pdf.fill_color "000000"
      end

      totals_bar(section, section[:total_title], section[:tree][:totals],
                 section[:total_columns], labels: section[:total_labels], bg: DARK_RED)
    end

    def render_node(section, node, depth)
      ensure_space(@pdf, 90)
      draw_group_header(node, depth) if node[:label].present?

      if node[:children].any?
        node[:children].each { |child| render_node(section, child, depth + 1) }
        # Nível com um único filho repete o subtotal que o filho já imprimiu.
        subtotal(section, node, depth) if node[:children].size > 1
      else
        render_leaf(section, node)
      end
    end

    # Nível folha (centro de custo): um ou mais blocos + a linha final do CC.
    # O rótulo vem das chaves ("Total faturado: …"), sem prefixo "Total ·".
    def render_leaf(section, node)
      blocks(section).each { |block| render_block(section, node, block) }
      totals_bar(section, nil, node[:totals], leaf_keys(section), labels: section[:leaf_labels])
    end

    def blocks(section)
      section[:blocks].presence ||
        [{ key: :default, title: nil, scope: :all, amount: section[:columns].last,
           flags: [], total_keys: [] }]
    end

    def leaf_keys(section)
      section[:leaf_total_keys].presence || section[:total_columns]
    end

    def render_block(section, node, block)
      rows = filter_rows(node[:rows], block[:scope])
      return if rows.empty?

      if block[:title].present?
        ensure_space(@pdf, 60)
        @pdf.move_down 3
        @pdf.fill_color "111827"
        @pdf.text safe(block[:title]), size: 8, style: :bold
        @pdf.fill_color "000000"
        @pdf.move_down 2
      end

      draw_table(section, rows, block)
      return if block[:total_keys].blank?

      totals_bar(section, nil, sum_rows(rows, block[:total_keys]),
                 block[:total_keys], labels: section[:leaf_labels])
    end

    def filter_rows(rows, scope)
      case scope
      when :received then rows.select { |r| r[:received].to_d.positive? }
      when :open     then rows.select { |r| r[:open] }
      else rows
      end
    end

    def sum_rows(rows, keys)
      Array(keys).index_with { |key| rows.sum { |row| row[key] || 0 } }
    end

    def draw_group_header(node, depth)
      @pdf.move_down depth == 1 ? 8 : 5
      size, color = case depth
                    when 1 then [12, DARK_RED]
                    when 2 then [10, RED]
                    else [9, "111827"]
                    end
      @pdf.fill_color color
      label = node[:label].to_s
      label = "#{label} (#{node[:sublabel]})" if node[:sublabel].present?
      @pdf.text safe(label), size: size, style: :bold
      @pdf.fill_color "000000"
      @pdf.move_down 3
    end

    # --- Tabela --------------------------------------------------------------

    def draw_table(section, rows, block)
      columns = section[:columns]
      headers = HEADERS.merge(section[:headers] || {})
      table   = [columns.map { |c| headers.fetch(c) }]
      partial_rows = []
      open_rows    = []

      rows.each do |row|
        table << columns.map { |c| cell_for(row, c, block) }
        if row[:partial] && block[:flags].include?(:partial)
          partial_rows << table.size - 1
        elsif row[:open] && !row[:partial] && block[:flags].include?(:open)
          open_rows << table.size - 1
        end
      end

      @pdf.table(table, width: @pdf.bounds.width, header: true,
                 cell_style: { size: 8, padding: [3, 5] }) do |t|
        columns.each_with_index do |c, i|
          t.column(i).align = :right  if NUMERIC.include?(c)
          t.column(i).align = :center if CENTERED.include?(c)
        end

        t.row(0).background_color = GRAY_HEAD
        t.row(0).font_style       = :bold
        t.row(0).text_color       = MUTED
        t.row(0).align            = :center

        partial_rows.each { |r| t.row(r).background_color = PARTIAL_BG }
        open_rows.each    { |r| t.row(r).background_color = OPEN_BG }

        t.cells.borders      = [:bottom]
        t.cells.border_color = GRAY_LINE
        t.row(0).borders     = [:top, :bottom]
      end
      @pdf.move_down 4
    end

    # A coluna monetária do bloco troca de conteúdo (faturado / recebido /
    # em aberto) conforme `block[:amount]`.
    def cell_for(row, column, block)
      # Colunas neutralizadas pelo bloco (ex.: DT BAIXA no bloco de em aberto).
      return "" if Array(block[:blank_columns]).include?(column)

      case column
      when :value, :received, :balance
        brl(row[block[:amount]])
      when :issued_at, :payment_date, :last_payment
        fmt_date(row[column])
      else
        safe(row[column].to_s)
      end
    end

    # --- Totais --------------------------------------------------------------

    def subtotal(section, node, depth)
      totals_bar(section, "Subtotal #{node[:label]}", node[:totals],
                 section[:total_columns], labels: section[:total_labels], depth: depth)
    end

    # Linha de total: "Rótulo · Faturado: R$ … · Recebido: … · Em aberto: …".
    def totals_bar(section, label, totals, keys, labels:, bg: nil, depth: nil)
      keys = Array(keys)
      return if keys.empty?

      labels = labels.presence || HEADERS
      text = [label.to_s.presence, *keys.map { |k| "#{labels.fetch(k, HEADERS[k])}: #{brl(totals[k])}" }]
               .compact.join(" · ")

      ensure_space(@pdf, 40)
      @pdf.move_down 2
      @pdf.table([[safe(text)]], width: @pdf.bounds.width,
                 cell_style: { size: bg ? 9 : 8, padding: [4, 5] }) do |t|
        t.column(0).align = :right
        if bg
          t.cells.background_color = bg
          t.cells.text_color       = "FFFFFF"
        else
          t.cells.background_color = depth == 1 ? GRAY_HEAD : GRAY_SUB
        end
        t.cells.font_style = :bold
        t.cells.borders    = []
      end
      @pdf.move_down bg ? 8 : 4
    end

    # Resumo final consolidado, sem duplicar CCs com vários coordenadores.
    def grand_summary
      return unless @data[:tipo] == :ambos

      s = @data[:summary]
      ensure_space(@pdf, 50)
      @pdf.move_down 6
      row = [["TOTAL GERAL", "Faturado: #{brl(s[:faturado])}",
              "Recebido: #{brl(s[:recebido])}", "Em Aberto: #{brl(s[:em_aberto])}"]]

      @pdf.table(row, width: @pdf.bounds.width, cell_style: { size: 10, padding: [6, 5] }) do |t|
        t.columns(1..3).align = :right
        t.cells.background_color = DARK_RED
        t.cells.text_color       = "FFFFFF"
        t.cells.font_style       = :bold
        t.cells.borders          = []
      end
    end
  end
end
