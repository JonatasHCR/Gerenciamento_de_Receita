require "caxlsx"

module Reports
  # Estilos comuns às planilhas de relatório (caxlsx).
  module XlsxStyling
    BORDER = { border: { style: :thin, color: "FF999999", edges: [:top, :bottom, :left, :right] } }.freeze

    def build_styles(wb)
      {
        title:  wb.styles.add_style(b: true, sz: 14, alignment: { horizontal: :center, vertical: :center },
                                    bg_color: "FF7F1D1D", fg_color: "FFFFFFFF"),
        header: wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                    bg_color: "FFB91C1C", fg_color: "FFFFFFFF", **BORDER),
        legend: wb.styles.add_style(sz: 9, i: true, fg_color: "FF92400E"),
        cell:   wb.styles.add_style(sz: 10, alignment: { vertical: :center }, **BORDER),
        date:   wb.styles.add_style(sz: 10, format_code: "dd/mm/yy", alignment: { horizontal: :center }, **BORDER),
        money:  wb.styles.add_style(sz: 10, format_code: 'R$ #,##0.00', **BORDER),
        p_cell:  wb.styles.add_style(sz: 10, alignment: { vertical: :center }, bg_color: "FFFEF3C7", **BORDER),
        p_date:  wb.styles.add_style(sz: 10, format_code: "dd/mm/yy", alignment: { horizontal: :center }, bg_color: "FFFEF3C7", **BORDER),
        p_money: wb.styles.add_style(sz: 10, format_code: 'R$ #,##0.00', bg_color: "FFFEF3C7", **BORDER),
        o_cell:  wb.styles.add_style(sz: 10, alignment: { vertical: :center }, bg_color: "FFFEF9C3", **BORDER),
        o_date:  wb.styles.add_style(sz: 10, format_code: "dd/mm/yy", alignment: { horizontal: :center }, bg_color: "FFFEF9C3", **BORDER),
        o_money: wb.styles.add_style(sz: 10, format_code: 'R$ #,##0.00', bg_color: "FFFEF9C3", **BORDER),
        # Cabeçalhos de nível de agrupamento (1 = mais externo).
        group1: wb.styles.add_style(b: true, sz: 12, fg_color: "FF7F1D1D", bg_color: "FFF3F4F6"),
        group2: wb.styles.add_style(b: true, sz: 11, fg_color: "FFB91C1C"),
        group3: wb.styles.add_style(b: true, sz: 10, fg_color: "FF111827"),
        sub_label:   wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :right }, bg_color: "FFEFF6FF", **BORDER),
        sub_money:   wb.styles.add_style(b: true, sz: 10, format_code: 'R$ #,##0.00', bg_color: "FFEFF6FF", **BORDER),
        total_label: wb.styles.add_style(b: true, sz: 10, alignment: { horizontal: :right }, bg_color: "FFF3F4F6", **BORDER),
        total_money: wb.styles.add_style(b: true, sz: 10, format_code: 'R$ #,##0.00', bg_color: "FFF3F4F6", **BORDER)
      }
    end
  end
end
