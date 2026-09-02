require "caxlsx"

module Reports
  # Excel do Relatório de Movimentação — uma aba por seção. Espelha o PDF:
  # dentro de cada centro de custo a seção pode ter mais de um BLOCO
  # (recebido / em aberto), e dos subtotais para cima os valores saem juntos.
  class MovementXlsx
    include XlsxStyling

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

    MONEY = %i[value received balance].freeze
    DATES = %i[issued_at last_payment payment_date].freeze
    SHEET_NAMES = { faturamento: "Faturamento", recebimento: "Recebimentos" }.freeze

    LEGEND = { partial: "Amarelo escuro = recebida em parte.",
               open:    "Amarelo claro = sem nenhum recebimento." }.freeze

    def initialize(report_data, filter_label: nil, period_label: nil)
      @data         = report_data
      @filter_label = filter_label
      @period_label = period_label
    end

    def call
      package = Axlsx::Package.new
      wb = package.workbook
      @s = build_styles(wb)

      @data[:sections].each do |section|
        wb.add_worksheet(name: SHEET_NAMES.fetch(section[:kind])) { |sheet| build_sheet(sheet, section) }
      end

      package.to_stream.read
    end

    private

    def build_sheet(sheet, section)
      columns = section[:columns]
      headers = HEADERS.merge(section[:headers] || {})
      last    = Axlsx.col_ref(columns.size - 1)

      sheet.add_row ["RELATÓRIO DE MOVIMENTAÇÃO — #{section[:title].upcase}"], style: @s[:title]
      sheet.merge_cells("A1:#{last}1")
      sheet.add_row [subtitle], style: @s[:legend]
      sheet.merge_cells("A2:#{last}2")
      if (legend = legend_text(section)).present?
        sheet.add_row [legend], style: @s[:legend]
        sheet.merge_cells("A3:#{last}3")
      end
      sheet.add_row columns.map { |c| headers.fetch(c) }, style: @s[:header]

      section[:tree][:groups].each { |node| add_node(sheet, section, node, 1) }
      add_totals_row(sheet, section, section[:total_title], section[:tree][:totals],
                     section[:total_columns], section[:total_labels], @s[:total_label])

      sheet.column_widths(*widths(columns))
    end

    def subtitle
      [@period_label.presence || "Período: todos os lançamentos",
       snapshot_text, @filter_label].compact_blank.join(" · ")
    end

    def legend_text(section)
      used = Array(section[:blocks]).flat_map { |b| Array(b[:flags]) }.uniq
      LEGEND.values_at(*(LEGEND.keys & used)).join(" · ")
    end

    def snapshot_text
      return nil if @data[:period_end].blank?
      "Situação apurada em #{I18n.l(@data[:period_end])}: baixa posterior não é considerada."
    end

    def add_node(sheet, section, node, depth)
      if node[:label].present?
        label = node[:sublabel].present? ? "#{node[:label]} (#{node[:sublabel]})" : node[:label]
        sheet.add_row(["#{'    ' * (depth - 1)}#{label}"], style: @s[:"group#{[depth, 3].min}"])
      end

      if node[:children].any?
        node[:children].each { |child| add_node(sheet, section, child, depth + 1) }
        return if node[:label].blank? || node[:children].size == 1
        add_totals_row(sheet, section, "Subtotal #{node[:label]}", node[:totals],
                       section[:total_columns], section[:total_labels], @s[:sub_label])
      else
        add_leaf(sheet, section, node)
      end
    end

    def add_leaf(sheet, section, node)
      blocks(section).each { |block| add_block(sheet, section, node, block) }
      add_totals_row(sheet, section, nil, node[:totals], leaf_keys(section),
                     section[:leaf_labels], @s[:sub_label])
    end

    def blocks(section)
      section[:blocks].presence ||
        [{ key: :default, title: nil, scope: :all, amount: section[:columns].last,
           flags: [], total_keys: [] }]
    end

    def leaf_keys(section)
      section[:leaf_total_keys].presence || section[:total_columns]
    end

    def add_block(sheet, section, node, block)
      rows = filter_rows(node[:rows], block[:scope])
      return if rows.empty?

      sheet.add_row([block[:title]], style: @s[:group3]) if block[:title].present?
      rows.each { |row| add_item_row(sheet, section, row, block) }
      return if block[:total_keys].blank?

      add_totals_row(sheet, section, nil, sum_rows(rows, block[:total_keys]),
                     block[:total_keys], section[:leaf_labels], @s[:sub_label])
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

    def add_item_row(sheet, section, row, block)
      columns = section[:columns]
      prefix  = if row[:partial] && block[:flags].include?(:partial) then "p_"
                elsif row[:open] && !row[:partial] && block[:flags].include?(:open) then "o_"
                else ""
                end

      values = columns.map { |c| cell_value(row, c, block) }
      styles = columns.map { |c| @s[:"#{prefix}#{style_key(c)}"] }
      types  = columns.map { |c| MONEY.include?(c) ? :float : (DATES.include?(c) ? :date : :string) }

      sheet.add_row(values, style: styles, types: types)
    end

    # A coluna monetária do bloco troca de conteúdo conforme `block[:amount]`.
    def cell_value(row, column, block)
      # Colunas neutralizadas pelo bloco (ex.: DT BAIXA no bloco de em aberto).
      return nil if Array(block[:blank_columns]).include?(column)

      MONEY.include?(column) ? row[block[:amount]] : row[column]
    end

    def style_key(column)
      return "money" if MONEY.include?(column)
      return "date"  if DATES.include?(column)
      "cell"
    end

    # Linha consolidada, no mesmo formato do PDF:
    # "Rótulo · Faturado: R$ … · Recebido: … · Em aberto: …", mesclada na largura.
    def add_totals_row(sheet, section, label, totals, keys, labels, label_style)
      keys = Array(keys)
      return if keys.empty?

      columns = section[:columns]
      labels  = labels.presence || HEADERS
      text = [label.to_s.presence,
              *keys.map { |k| "#{labels.fetch(k, HEADERS[k])}: #{brl(totals[k])}" }].compact.join(" · ")

      values = Array.new(columns.size)
      styles = Array.new(columns.size) { @s[:cell] }
      values[0] = text
      styles[0] = label_style

      sheet.add_row(values, style: styles, types: Array.new(columns.size, :string))
      row_number = sheet.rows.size
      sheet.merge_cells("A#{row_number}:#{Axlsx.col_ref(columns.size - 1)}#{row_number}")
    end

    def brl(value)
      ActiveSupport::NumberHelper.number_to_currency(
        value || 0, unit: "R$ ", separator: ",", delimiter: ".", precision: 2
      )
    end

    def widths(columns)
      columns.map do |c|
        case c
        when :number then 18
        when :cr_code then 12
        when :contract_number then 18
        when :issued_at, :payment_date, :last_payment then 14
        else 20
        end
      end
    end
  end
end
