require "prawn"
require "prawn/table"

module CostCenters
  # Ficha do contrato: os dados da tela do CC + histórico de reajustes.
  # Sem notas fiscais e sem a observação dos reajustes.
  class ContractSheetPdf
    include Reports::PdfStyling
    Prawn::Fonts::AFM.hide_m17n_warning = true

    LABEL_WIDTH = 150

    def initialize(cost_center, generated_by: nil)
      @cc           = cost_center
      @generated_by = generated_by
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 50, 40])
      document_header(@pdf, "Ficha do Contrato",
                      ["#{@cc.cr_code} — #{@cc.description}", "Emitido em #{I18n.l(Date.current)}"])
      details
      adjustments
      page_footer(@pdf, @generated_by)
      @pdf.render
    end

    private

    def details
      section_title("Dados do Contrato")
      parcial = (@cc.participation || 0) < 1
      rows = [
        ["Cliente",            @cc.client&.name],
        ["Nº do Contrato",     @cc.contract_number],
        ["Centro de Resultado", @cc.cr_code],
        ["Descrição",          @cc.description],
        ["Coordenador(es)",    @cc.coordinator],
        ["Participação UFC",   pct(@cc.participation || 0)],
        ["Início",             @cc.start_date&.strftime("%d/%m/%Y")],
        ["Data Final",         @cc.end_date&.strftime("%d/%m/%Y")],
        ["Valor do Contrato",  brl(@cc.value)],
        [parcial ? "Saldo UFC (participação aplicada)" : "Saldo", brl(@cc.saldo_ufc)]
      ]
      rows << ["Saldo total do contrato", brl(@cc.saldo)] if parcial
      rows << ["Objeto", @cc.object_text] if @cc.object_text.present?

      data = rows.map { |label, value| [safe(label), safe(value.presence || "—")] }
      @pdf.table(data, column_widths: [LABEL_WIDTH, @pdf.bounds.width - LABEL_WIDTH],
                       cell_style: { size: 10, padding: [5, 6], borders: [:bottom], border_color: GRAY_LINE }) do |t|
        t.column(0).font_style = :bold
        t.column(0).text_color = MUTED
        t.column(0).background_color = GRAY_HEAD
      end
      @pdf.move_down 18
    end

    def adjustments
      list = @cc.adjustments.chronological.to_a
      ensure_space(@pdf, 90)
      section_title("Reajustes")

      if list.empty?
        @pdf.text "Nenhum reajuste registrado.", size: 10, color: MUTED
        return
      end

      data = [["Data", "Tipo", "Anterior", "Novo", "Acréscimo"].map { |h| safe(h) }]
      list.each do |adj|
        data << if adj.valor?
          [adj.created_at.to_date.strftime("%d/%m/%Y"), "Valor", brl(adj.previous_value), brl(adj.new_value),
           adj.value_delta&.positive? ? "+#{brl(adj.value_delta)}" : ""]
        else
          [adj.created_at.to_date.strftime("%d/%m/%Y"), "Prazo", adj.previous_date&.strftime("%d/%m/%Y") || "—",
           adj.new_date&.strftime("%d/%m/%Y").to_s, ""]
        end
      end

      @pdf.table(data, header: true, width: @pdf.bounds.width,
                       cell_style: { size: 9, padding: [4, 6], borders: [:bottom], border_color: GRAY_LINE }) do |t|
        t.columns(2..4).align = :right
        t.row(0).background_color = GRAY_HEAD
        t.row(0).font_style       = :bold
        t.row(0).text_color       = MUTED
        t.row(0).borders          = [:top, :bottom]
      end
    end

    def section_title(text)
      @pdf.fill_color DARK_RED
      @pdf.text safe(text), size: 12, style: :bold
      @pdf.fill_color "000000"
      @pdf.move_down 6
    end
  end
end
