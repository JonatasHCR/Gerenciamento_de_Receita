require "prawn"

module CostCenters
  # Ficha do contrato no visual da tela do CC: cartão de dados em duas colunas
  # + cartão de reajustes com etiquetas. Sem notas fiscais e sem a observação
  # dos reajustes.
  class ContractSheetPdf
    include Reports::PdfStyling
    Prawn::Fonts::AFM.hide_m17n_warning = true

    TEXT      = "111827".freeze
    GREEN     = "16A34A".freeze
    NEGATIVE  = "DC2626".freeze
    ORANGE_BG = "FFEDD5".freeze
    ORANGE_FG = "C2410C".freeze
    BLUE_BG   = "DBEAFE".freeze
    BLUE_FG   = "1D4ED8".freeze
    PAD       = 16
    GAP       = 20

    def initialize(cost_center, generated_by: nil)
      @cc           = cost_center
      @generated_by = generated_by
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 50, 40])
      header
      card("Dados do Contrato") { details }
      @pdf.move_down 16
      ensure_space(@pdf, 110)
      card("Reajustes") { adjustments }
      page_footer(@pdf, @generated_by)
      @pdf.render
    end

    private

    def header
      @pdf.fill_color RED
      @pdf.text "UFC Engenharia", size: 11, style: :bold
      @pdf.move_down 6
      @pdf.fill_color TEXT
      @pdf.text safe("#{@cc.cr_code} — #{@cc.description}"), size: 17, style: :bold, leading: 2
      @pdf.move_down 2
      @pdf.fill_color MUTED
      @pdf.text safe("Ficha do Contrato · Emitido em #{I18n.l(Date.current)}"), size: 9
      @pdf.move_down 16
    end

    def details
      parcial = (@cc.participation || 0) < 1
      saldo   = @cc.saldo_ufc
      grid([
        { label: "Cliente",           value: @cc.client&.name },
        { label: "Nº do Contrato",    value: @cc.contract_number },
        { label: "Coordenador(es)",   value: @cc.coordinator },
        { label: "Participação UFC",  value: pct(@cc.participation || 0) },
        { label: "Início",            value: @cc.start_date&.strftime("%d/%m/%Y") },
        { label: "Data Final",        value: @cc.end_date&.strftime("%d/%m/%Y") },
        { label: "Valor do Contrato", value: brl(@cc.value) },
        { label: parcial ? "Saldo UFC (participação aplicada)" : "Saldo", value: brl(saldo),
          color: saldo.negative? ? NEGATIVE : GREEN,
          sub: ("Saldo total do contrato: #{brl(@cc.saldo)}" if parcial) }
      ])
      return if @cc.object_text.blank?

      @pdf.stroke_color GRAY_LINE
      @pdf.stroke_horizontal_rule
      @pdf.move_down 10
      field(label: "Objeto", value: @cc.object_text, size: 10, style: :normal)
    end

    def adjustments
      list = @cc.adjustments.chronological.to_a
      if list.empty?
        @pdf.fill_color MUTED
        @pdf.text "Nenhum reajuste registrado.", size: 10
        return
      end

      list.each_with_index do |adj, i|
        if i.positive?
          @pdf.stroke_color GRAY_LINE
          @pdf.stroke_horizontal_rule
          @pdf.move_down 8
        end
        adjustment_row(adj)
      end
    end

    def adjustment_row(adj)
      bg, fg, label = adj.valor? ? [ORANGE_BG, ORANGE_FG, "Valor"] : [BLUE_BG, BLUE_FG, "Prazo"]
      line = if adj.valor?
        delta = adj.value_delta
        "#{brl(adj.previous_value)}  »  <b>#{brl(adj.new_value)}</b>" +
          (delta&.positive? ? "  <color rgb='#{GREEN}'>(+#{brl(delta)})</color>" : "")
      else
        "#{adj.previous_date&.strftime('%d/%m/%Y') || '—'}  »  <b>#{adj.new_date&.strftime('%d/%m/%Y')}</b>"
      end

      top = @pdf.cursor
      @pdf.fill_color bg
      @pdf.fill_rounded_rectangle [0, top], 42, 15, 7
      @pdf.fill_color fg
      @pdf.text_box label, at: [0, top - 4], width: 42, height: 12, size: 7.5, style: :bold, align: :center
      @pdf.bounding_box([54, top], width: @pdf.bounds.width - 54) do
        @pdf.fill_color TEXT
        @pdf.text safe(line), size: 10, inline_format: true
        @pdf.move_down 2
        @pdf.fill_color MUTED
        @pdf.text I18n.l(adj.created_at, format: :short), size: 8
      end
      @pdf.move_down 8
    end

    # Cartão branco com borda arredondada, como os da tela.
    def card(title)
      @pdf.bounding_box([0, @pdf.cursor], width: @pdf.bounds.width) do
        @pdf.move_down PAD
        @pdf.indent(PAD, PAD) do
          @pdf.fill_color "374151"
          @pdf.text safe(title), size: 11, style: :bold
          @pdf.move_down 12
          yield
        end
        @pdf.move_down PAD - 8
        @pdf.stroke_color GRAY_LINE
        @pdf.line_width 0.8
        @pdf.stroke_rounded_rectangle [0, @pdf.bounds.top], @pdf.bounds.width, @pdf.bounds.height, 8
      end
      @pdf.fill_color "000000"
    end

    # Posição guardada em y absoluto: o cartão estica enquanto desenha, e um
    # cursor relativo guardado antes da 1ª coluna já não vale para a 2ª.
    def grid(fields)
      col_w = (@pdf.bounds.width - GAP) / 2
      fields.each_slice(2) do |pair|
        top = @pdf.y
        bottoms = pair.each_with_index.map do |f, i|
          @pdf.y = top
          @pdf.bounding_box([i * (col_w + GAP), @pdf.cursor], width: col_w) { field(**f) }
          @pdf.y
        end
        @pdf.y = bottoms.min
        @pdf.move_down 12
      end
    end

    def field(label:, value:, color: TEXT, sub: nil, size: 11, style: :bold)
      @pdf.fill_color MUTED
      @pdf.text safe(label.upcase), size: 7.5, character_spacing: 0.6
      @pdf.move_down 3
      @pdf.fill_color color
      @pdf.text safe(value.presence || "—"), size: size, style: style, leading: 2
      return unless sub

      @pdf.move_down 2
      @pdf.fill_color "9CA3AF"
      @pdf.text safe(sub), size: 8
    end
  end
end
