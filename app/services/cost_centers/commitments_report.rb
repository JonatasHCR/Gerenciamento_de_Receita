require "caxlsx"

module CostCenters
  # Gera o Excel "RELAÇÃO DE COMPROMISSOS - MOD" dos centros de custo.
  # Colunas: Nº Contrato, Contratante, Centro de Resultado, Objeto/Natureza,
  # Início, Fim, Valor, % a Executar, Saldo.
  class CommitmentsReport
    HEADERS = [
      "Nº DO CONTRATO", "CONTRATANTE", "CENTRO DE RESULTADO",
      "OBJETO OU NATUREZA DOS SERVIÇOS", "INÍCIO", "FIM",
      "VALOR", "% A EXECUTAR", "SALDO"
    ].freeze

    def initialize(cost_centers)
      @cost_centers = cost_centers
    end

    def call
      package = Axlsx::Package.new
      wb = package.workbook

      styles = build_styles(wb)

      # Faturado PRINCIPAL por CC numa única query (evita N+1 de saldo/%).
      principal = Invoice.principal.where(cost_center_id: @cost_centers.map(&:id))
                         .group(:cost_center_id).sum(:value)

      wb.add_worksheet(name: "Compromissos") do |sheet|
        sheet.add_row ["RELAÇÃO DE COMPROMISSOS - MOD"], style: styles[:title]
        sheet.merge_cells("A1:I1")
        sheet.add_row [], style: styles[:title] # linha em branco
        sheet.add_row HEADERS, style: styles[:header]

        total_valor = total_saldo = 0
        @cost_centers.each do |cc|
          valor = cc.value.to_f
          saldo = valor - (principal[cc.id] || 0).to_f
          pct   = valor.zero? ? 0 : (saldo / valor * 100).round(2)
          total_valor += valor
          total_saldo += saldo
          sheet.add_row(
            [
              cc.contract_number, cc.client&.name, cc.cr_code, cc.object_text,
              fmt_date(cc.start_date), fmt_date(cc.end_date),
              valor, pct, saldo
            ],
            style: [styles[:cell], styles[:cell], styles[:cell], styles[:cell],
                    styles[:date], styles[:date], styles[:money], styles[:pct], styles[:money]],
            types: [:string, :string, :string, :string, :string, :string, :float, :float, :float]
          )
        end

        # Linha de total
        sheet.add_row(
          ["", "", "", "", "", "TOTAL", total_valor, nil, total_saldo],
          style: [styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:cell],
                  styles[:total_label], styles[:total_money], styles[:cell], styles[:total_money]]
        )

        sheet.column_widths 16, 30, 18, 42, 12, 12, 16, 13, 16
      end

      package.to_stream.read
    end

    private

    def fmt_date(date)
      date&.strftime("%d/%m/%Y") || ""
    end

    def build_styles(wb)
      thin = { style: :thin, color: "FF999999" }
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
        cell:  wb.styles.add_style(sz: 10, alignment: { vertical: :center }, **border),
        date:  wb.styles.add_style(sz: 10, format_code: "dd/mm/yyyy", alignment: { horizontal: :center }, **border),
        money: wb.styles.add_style(sz: 10, format_code: 'R$ #,##0.00', **border),
        pct:   wb.styles.add_style(sz: 10, format_code: '0.00"%"', alignment: { horizontal: :center }, **border),
        total_label: wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :right }, **border),
        total_money: wb.styles.add_style(b: true, sz: 10, format_code: 'R$ #,##0.00', **border)
      }
    end
  end
end
