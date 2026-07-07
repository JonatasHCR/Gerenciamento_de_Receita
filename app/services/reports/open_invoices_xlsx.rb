require "caxlsx"

module Reports
  # Excel da "Relação das Faturas em Aberto", por cliente → centro de custo.
  # Colunas: CLIENTE, NF, DT EMISSÃO, CC, CONTRATO, VALOR (saldo em aberto).
  class OpenInvoicesXlsx
    HEADERS = ["CLIENTE", "NF", "DT EMISSÃO", "CC", "CONTRATO", "VALOR"].freeze

    def initialize(report_data)
      @data = report_data
    end

    def call
      package = Axlsx::Package.new
      wb = package.workbook
      s = build_styles(wb)

      wb.add_worksheet(name: "Faturas em Aberto") do |sheet|
        sheet.add_row ["RELAÇÃO DAS FATURAS EM ABERTO"], style: s[:title]
        sheet.merge_cells("A1:F1")
        sheet.add_row ["Linhas em amarelo = fatura parcialmente paga (já teve recebimento). VALOR = saldo em aberto."],
                      style: s[:legend]
        sheet.merge_cells("A2:F2")
        sheet.add_row HEADERS, style: s[:header]

        @data.each do |group|
          client = group[:client]
          group[:cost_centers].each do |cc_group|
            cc = cc_group[:cc]
            cc_group[:invoices].each do |inv|
              partial = inv.partially_paid?
              sheet.add_row(
                [client&.name, inv.number, inv.issued_at, cc.cr_code, cc.contract_number, inv.balance],
                style: partial ? [s[:p_cell], s[:p_cell], s[:p_date], s[:p_cell], s[:p_cell], s[:p_money]]
                               : [s[:cell], s[:cell], s[:date], s[:cell], s[:cell], s[:money]],
                types: [:string, :string, :date, :string, :string, :float]
              )
            end
            sheet.add_row(
              ["", "", "", cc.cr_code, "Subtotal", cc_group[:subtotal]],
              style: [s[:cell], s[:cell], s[:cell], s[:sub_label], s[:sub_label], s[:sub_money]],
              types: [:string, :string, :string, :string, :string, :float]
            )
          end
          sheet.add_row(
            ["", "", "", "", "TOTAL #{client&.name}", group[:total]],
            style: [s[:cell], s[:cell], s[:cell], s[:cell], s[:total_label], s[:total_money]],
            types: [:string, :string, :string, :string, :string, :float]
          )
        end

        if @data.size > 1
          sheet.add_row(
            ["", "", "", "", "TOTAL GERAL", @data.sum { |g| g[:total] }],
            style: [s[:cell], s[:cell], s[:cell], s[:cell], s[:total_label], s[:total_money]],
            types: [:string, :string, :string, :string, :string, :float]
          )
        end

        sheet.column_widths 28, 16, 14, 10, 16, 18
      end

      package.to_stream.read
    end

    private

    def build_styles(wb)
      border = { border: { style: :thin, color: "FF999999", edges: [:top, :bottom, :left, :right] } }
      {
        title:  wb.styles.add_style(b: true, sz: 14, alignment: { horizontal: :center, vertical: :center },
                                    bg_color: "FF7F1D1D", fg_color: "FFFFFFFF"),
        header: wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                    bg_color: "FFB91C1C", fg_color: "FFFFFFFF", **border),
        legend: wb.styles.add_style(sz: 9, i: true, fg_color: "FF92400E"),
        cell:   wb.styles.add_style(sz: 10, alignment: { vertical: :center }, **border),
        date:   wb.styles.add_style(sz: 10, format_code: "dd/mm/yyyy", alignment: { horizontal: :center }, **border),
        money:  wb.styles.add_style(sz: 10, format_code: 'R$ #,##0.00', **border),
        p_cell:  wb.styles.add_style(sz: 10, alignment: { vertical: :center }, bg_color: "FFFEF3C7", **border),
        p_date:  wb.styles.add_style(sz: 10, format_code: "dd/mm/yyyy", alignment: { horizontal: :center }, bg_color: "FFFEF3C7", **border),
        p_money: wb.styles.add_style(sz: 10, format_code: 'R$ #,##0.00', bg_color: "FFFEF3C7", **border),
        sub_label:   wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :right }, bg_color: "FFEFF6FF", **border),
        sub_money:   wb.styles.add_style(b: true, sz: 10, format_code: 'R$ #,##0.00', bg_color: "FFEFF6FF", **border),
        total_label: wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :right }, bg_color: "FFF3F4F6", **border),
        total_money: wb.styles.add_style(b: true, sz: 10, format_code: 'R$ #,##0.00', bg_color: "FFF3F4F6", **border)
      }
    end
  end
end
