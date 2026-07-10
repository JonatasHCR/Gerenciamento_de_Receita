require "caxlsx"

module CostCenters
  # Gera o Excel "RELAÇÃO DE COMPROMISSOS - MOD" dos centros de custo.
  # Colunas: Nº Contrato, Contratante, Centro de Resultado, Objeto/Natureza,
  # Início, Fim, Valor, % a Executar, Saldo.
  class CommitmentsReport
    HEADERS = [
      "Nº DO CONTRATO", "CONTRATANTE", "CENTRO DE RESULTADO",
      "OBJETO OU NATUREZA DOS SERVIÇOS", "INÍCIO", "FIM",
      "VALOR", "% A EXECUTAR", "SALDO",
      "% UFC", "VALOR DO CONTRATO (TOTAL)", "FATURAMENTO GERAL",
      "SALDO DO CONTRATO (TOTAL)", "VALOR CONTRATO UFC", "SALDO UFC"
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
        sheet.merge_cells("A1:O1")
        sheet.add_row [], style: styles[:title]
        sheet.add_row HEADERS, style: styles[:header]

        total_valor = total_saldo = 0
        # Bloco UFC (colunas após o Saldo): só soma os CCs com participação < 100%,
        # pois para 100% essas colunas ficam em branco.
        t_valor_tot = t_fat = t_saldo_tot = t_valor_ufc = t_saldo_ufc = 0
        @cost_centers.each do |cc|
          valor = cc.value.to_f
          fat   = (principal[cc.id] || 0).to_f         # faturamento geral (principal)
          saldo = valor - fat                          # saldo total do contrato
          pct   = valor.zero? ? 0 : (saldo / valor * 100).round(2)
          part  = cc.participation.to_f                # 0..1
          saldo_ufc = saldo * part                     # saldo respeitando a participação

          total_valor += valor
          total_saldo += saldo_ufc                     # coluna "Saldo" usa o valor UFC

          # % UFC é SEMPRE preenchido. As demais colunas (valor/faturamento/saldo
          # totais e valor UFC) só fazem sentido com participação < 100%;
          # para 100% ficam em branco (já constam em Valor/Saldo).
          pct_ufc = (part * 100).round(2)
          if part < 1.0
            valor_ufc = valor * part
            ufc_cols  = [pct_ufc, valor, fat, saldo, valor_ufc, saldo_ufc]
            t_valor_tot += valor; t_fat += fat; t_saldo_tot += saldo
            t_valor_ufc += valor_ufc; t_saldo_ufc += saldo_ufc
          else
            ufc_cols = [pct_ufc, nil, nil, nil, nil, nil]
          end

          sheet.add_row(
            [
              cc.contract_number, cc.client&.name, cc.cr_code, cc.object_text,
              fmt_date(cc.start_date), fmt_date(cc.end_date),
              valor, pct, saldo_ufc, *ufc_cols
            ],
            style: [styles[:cell], styles[:cell], styles[:cell], styles[:cell],
                    styles[:date], styles[:date], styles[:money], styles[:pct], styles[:money],
                    styles[:pct], styles[:money], styles[:money], styles[:money], styles[:money], styles[:money]],
            types: [:string, :string, :string, :string, :string, :string,
                    :float, :float, :float, :float, :float, :float, :float, :float, :float]
          )
        end

        # Linha de total (bloco UFC soma só os CCs com participação < 100%)
        sheet.add_row(
          ["", "", "", "", "", "TOTAL", total_valor, nil, total_saldo,
           nil, t_valor_tot, t_fat, t_saldo_tot, t_valor_ufc, t_saldo_ufc],
          style: [styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:cell],
                  styles[:total_label], styles[:total_money], styles[:cell], styles[:total_money],
                  styles[:cell], styles[:total_money], styles[:total_money], styles[:total_money],
                  styles[:total_money], styles[:total_money]]
        )

        sheet.column_widths 16, 30, 18, 42, 12, 12, 16, 13, 16, 10, 22, 18, 22, 20, 16
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
