class LettersController < ApplicationController
  before_action :set_cost_center, only: [:generate]

  def generate
    authorize :letter, :generate?
    kind = params[:kind].presence_in(%w[principal reajuste]) || "principal"

    tpl = @cost_center.letter_template_for(kind)
    unless tpl
      redirect_to @cost_center, alert: "Envie o modelo de #{kind} deste CR antes de gerar a carta."
      return
    end

    invoice = @cost_center.invoices.find_by(id: params[:invoice_id])
    preview = params[:preview].present?

    # Preview mostra o próximo nº sem gravar; a geração final grava e consome a sequência.
    oficio =
      if preview
        Letter.oficio_number(@cost_center, Letter.next_sequence(@cost_center, Date.current.year), Date.current.year)
      else
        Letter.record!(cost_center: @cost_center, kind: kind, invoice: invoice, user: current_user).number
      end

    data = Letters::LetterData.new(
      cost_center:    @cost_center,
      kind:           kind,
      invoice:        invoice,
      periodo_inicio: params[:periodo_inicio],
      periodo_fim:    params[:periodo_fim],
      oficio:         oficio
    ).to_h

    docx = Letters::DocxMerge.new(tpl.content, data).call
    base = "carta_#{kind}_#{@cost_center.cr_code}_#{Date.current.strftime('%Y%m%d')}"

    if params[:output] == "pdf" || preview
      pdf = Letters::PdfConverter.new(docx).call
      send_data pdf, filename: "#{base}.pdf", type: "application/pdf",
                     disposition: preview ? "inline" : "attachment"
    else
      send_data docx, filename: "#{base}.docx",
                     type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                     disposition: "attachment"
    end
  rescue Letters::PdfConverter::ConversionError => e
    redirect_to @cost_center, alert: e.message
  end

  def letter_base
    authorize :letter, :manage?
    kind = params[:kind].presence_in(%w[principal reajuste]) || "principal"
    send_data Letters::BaseTemplateGenerator.new(kind).call,
              filename: "modelo_base_#{kind}.docx",
              type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
              disposition: "attachment"
  end

  private

  def set_cost_center
    @cost_center = CostCenter.find(params[:id])
  end
end
