require "prawn"
require "prawn/table"

module Reports
  # Estilo e utilidades comuns aos PDFs de relatório (prawn + fonte AFM/WinAnsi).
  # Todo texto passa por #safe — a fonte AFM só cobre CP1252, então glifos fora
  # do conjunto (ex.: "■") quebram o PDF.
  module PdfStyling
    RED         = "B91C1C".freeze
    DARK_RED    = "7F1D1D".freeze
    GRAY_HEAD   = "F3F4F6".freeze
    GRAY_LINE   = "E5E7EB".freeze
    GRAY_SUB    = "EFF6FF".freeze
    MUTED       = "6B7280".freeze
    PARTIAL_BG  = "FEF3C7".freeze  # amber-100 — NF parcialmente paga
    PARTIAL_DOT = "F59E0B".freeze  # amber-500 — swatch da legenda
    OPEN_BG     = "FEF9C3".freeze  # yellow-100 — NF em aberto sem recebimento
    OPEN_DOT    = "CA8A04".freeze  # yellow-600

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

    # Datas em coluna de tabela usam ano com 2 dígitos (dd/mm/aa) — cabe melhor
    # e é o formato pedido nos relatórios.
    def fmt_date(date)
      date&.strftime("%d/%m/%y") || ""
    end

    def truncate(text, length)
      return "" if text.blank?
      text.length > length ? "#{text[0, length - 1]}…" : text
    end

    def safe(text)
      text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
          .encode("UTF-8")
    end

    def document_header(pdf, title, lines = [])
      pdf.fill_color RED
      pdf.text "UFC Engenharia", size: 18, style: :bold
      pdf.fill_color "000000"
      pdf.text safe(title), size: 13, style: :bold
      pdf.fill_color MUTED
      Array(lines).compact_blank.each { |line| pdf.text safe(line), size: 10 }
      pdf.fill_color "000000"
      pdf.stroke_color GRAY_LINE
      pdf.stroke_horizontal_rule
      pdf.move_down 10
    end

    # Swatch da legenda desenhado como retângulo (nada de glifo fora do CP1252).
    def legend_swatch(pdf, fill, border, text)
      y = pdf.cursor
      pdf.fill_color fill
      pdf.fill_rectangle [0, y], 16, 9
      pdf.stroke_color border
      pdf.stroke_rectangle [0, y], 16, 9
      pdf.fill_color MUTED
      pdf.draw_text safe(text), at: [22, y - 7], size: 8
      pdf.fill_color "000000"
      pdf.move_down 13
    end

    # Quebra a página SÓ quando não caberia o cabeçalho + início da tabela.
    # Substitui o antigo `start_new_page` por grupo, que desperdiçava uma folha
    # inteira quando o grupo tinha um único contrato.
    def ensure_space(pdf, needed = 70)
      pdf.start_new_page if pdf.cursor < needed
    end

    def page_footer(pdf, generated_by)
      pdf.number_pages "Página <page> de <total>",
                       at: [0, -10], align: :right, size: 7, color: MUTED
      pdf.repeat(:all) do
        pdf.fill_color MUTED
        meta = "Gerado em #{I18n.l(Time.current, format: :short)}"
        meta += " por #{generated_by}" if generated_by.present?
        pdf.draw_text safe(meta), at: [0, -10], size: 7
        pdf.fill_color "000000"
      end
    end
  end
end
