require "caxlsx"

module CostCenters
  # Gera o Excel "RELAÇÃO DE COMPROMISSOS - MOD" dos centros de custo.
  # Colunas: Nº Contrato, Contratante, Centro de Resultado, Objeto/Natureza,
  # Início, Fim, Valor, % a Executar, Saldo + bloco UFC.
  #
  # `levels:` vem do Reports::ScopeFilter#levels(row_is_cost_center: true).
  # Vazio (padrão) = lista plana, idêntica ao comportamento anterior.
  class CommitmentsReport
    HEADERS = [
      "Nº DO CONTRATO", "CONTRATANTE", "CENTRO DE RESULTADO",
      "OBJETO OU NATUREZA DOS SERVIÇOS", "INÍCIO", "FIM",
      "VALOR", "% A EXECUTAR", "SALDO",
      "% UFC", "VALOR DO CONTRATO (TOTAL)", "FATURAMENTO GERAL",
      "SALDO DO CONTRATO (TOTAL)", "VALOR CONTRATO UFC", "SALDO UFC"
    ].freeze

    # Somatórios do bloco UFC: só contam os CCs com participação < 100%
    # (para 100% essas colunas ficam em branco).
    SUM_KEYS = %i[valor saldo_ufc u_valor_tot u_fat u_saldo_tot u_valor_ufc u_saldo_ufc].freeze

    def initialize(cost_centers, levels: [], filter_label: nil)
      @cost_centers = cost_centers
      @levels       = Array(levels)
      @filter_label = filter_label
    end

    def call
      package = Axlsx::Package.new
      wb = package.workbook
      @styles = build_styles(wb)

      wb.add_worksheet(name: "Compromissos") do |sheet|
        sheet.add_row ["RELAÇÃO DE COMPROMISSOS - MOD"], style: @styles[:title]
        sheet.merge_cells("A1:O1")
        sheet.add_row [@filter_label].compact_blank, style: @styles[:legend]
        sheet.add_row HEADERS, style: @styles[:header]

        tree[:groups].each { |node| add_node(sheet, node, 1) }
        add_total_row(sheet, "TOTAL GERAL", tree[:totals]) if @levels.any?

        sheet.column_widths 16, 30, 18, 42, 12, 12, 16, 13, 16, 10, 22, 18, 22, 20, 16
      end

      package.to_stream.read
    end

    private

    def tree
      @tree ||= Reports::GroupTree.build(rows, levels: @levels, sum_keys: SUM_KEYS)
    end

    # Faturado PRINCIPAL por CC numa única query (evita N+1 de saldo/%).
    def rows
      @rows ||= begin
        principal = Invoice.principal.where(cost_center_id: @cost_centers.map(&:id))
                           .group(:cost_center_id).sum(:value)

        @cost_centers.map do |cc|
          valor = cc.value.to_f
          fat   = (principal[cc.id] || 0).to_f   # faturamento geral (principal)
          saldo = valor - fat                    # saldo total do contrato
          part  = cc.participation.to_f          # 0..1
          full  = part >= 1.0

          {
            cc: cc, client: cc.client, valor: valor, fat: fat, saldo: saldo, part: part,
            pct: valor.zero? ? 0 : (saldo / valor * 100).round(2),
            pct_ufc: (part * 100).round(2),
            valor_ufc: valor * part,
            saldo_ufc: saldo * part,
            u_valor_tot: full ? 0 : valor,
            u_fat:       full ? 0 : fat,
            u_saldo_tot: full ? 0 : saldo,
            u_valor_ufc: full ? 0 : valor * part,
            u_saldo_ufc: full ? 0 : saldo * part
          }
        end
      end
    end

    def add_node(sheet, node, depth)
      if node[:label].present?
        sheet.add_row(["#{'    ' * (depth - 1)}#{node[:label]}"], style: @styles[:"group#{[depth, 2].min}"])
      end

      if node[:children].any?
        node[:children].each { |child| add_node(sheet, child, depth + 1) }
      else
        node[:rows].each { |row| add_item_row(sheet, row) }
      end

      return if (node[:label].blank? && @levels.any?) || node[:children].size == 1
      add_total_row(sheet, node[:label].present? ? "Subtotal" : "TOTAL", node[:totals])
    end

    def add_item_row(sheet, row)
      cc = row[:cc]
      # % UFC é SEMPRE preenchido. As demais colunas (valor/faturamento/saldo
      # totais e valor UFC) só fazem sentido com participação < 100%;
      # para 100% ficam em branco (já constam em Valor/Saldo).
      ufc_cols = if row[:part] < 1.0
                   [row[:pct_ufc], row[:valor], row[:fat], row[:saldo], row[:valor_ufc], row[:saldo_ufc]]
                 else
                   [row[:pct_ufc], nil, nil, nil, nil, nil]
                 end

      sheet.add_row(
        [
          cc.contract_number, cc.client&.name, cc.cr_code, cc.object_text,
          fmt_date(cc.start_date), fmt_date(cc.end_date),
          row[:valor], row[:pct], row[:saldo_ufc], *ufc_cols
        ],
        style: [@styles[:cell], @styles[:cell], @styles[:cell], @styles[:cell],
                @styles[:date], @styles[:date], @styles[:money], @styles[:pct], @styles[:money],
                @styles[:pct], @styles[:money], @styles[:money], @styles[:money], @styles[:money], @styles[:money]],
        types: [:string, :string, :string, :string, :string, :string,
                :float, :float, :float, :float, :float, :float, :float, :float, :float]
      )
    end

    def add_total_row(sheet, label, totals)
      sheet.add_row(
        ["", "", "", "", "", label, totals[:valor], nil, totals[:saldo_ufc],
         nil, totals[:u_valor_tot], totals[:u_fat], totals[:u_saldo_tot],
         totals[:u_valor_ufc], totals[:u_saldo_ufc]],
        style: [@styles[:cell], @styles[:cell], @styles[:cell], @styles[:cell], @styles[:cell],
                @styles[:total_label], @styles[:total_money], @styles[:cell], @styles[:total_money],
                @styles[:cell], @styles[:total_money], @styles[:total_money], @styles[:total_money],
                @styles[:total_money], @styles[:total_money]]
      )
    end

    def fmt_date(date)
      date&.strftime("%d/%m/%y") || ""
    end

    def build_styles(wb)
      border = { border: { style: :thin, color: "FF999999", edges: [:top, :bottom, :left, :right] } }

      {
        title: wb.styles.add_style(
          b: true, sz: 14, alignment: { horizontal: :center, vertical: :center },
          bg_color: "FF7F1D1D", fg_color: "FFFFFFFF"
        ),
        header: wb.styles.add_style(
          b: true, sz: 10, alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          bg_color: "FFB91C1C", fg_color: "FFFFFFFF", **border
        ),
        legend: wb.styles.add_style(sz: 9, i: true, fg_color: "FF6B7280"),
        group1: wb.styles.add_style(b: true, sz: 12, fg_color: "FF7F1D1D", bg_color: "FFF3F4F6"),
        group2: wb.styles.add_style(b: true, sz: 11, fg_color: "FFB91C1C"),
        cell:  wb.styles.add_style(sz: 10, alignment: { vertical: :center }, **border),
        date:  wb.styles.add_style(sz: 10, format_code: "dd/mm/yy", alignment: { horizontal: :center }, **border),
        money: wb.styles.add_style(sz: 10, format_code: 'R$ #,##0.00', **border),
        pct:   wb.styles.add_style(sz: 10, format_code: '0.00"%"', alignment: { horizontal: :center }, **border),
        total_label: wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :right }, **border),
        total_money: wb.styles.add_style(b: true, sz: 10, format_code: 'R$ #,##0.00', **border)
      }
    end
  end
end
