module CostCenters
  class LetterTemplatesController < ApplicationController
    before_action :set_cost_center

    def create
      authorize :letter, :manage?
      file = params[:file]
      unless file.respond_to?(:read)
        redirect_to @cost_center, alert: "Selecione um arquivo .docx."
        return
      end

      tpl = @cost_center.letter_templates.find_or_initialize_by(kind: params[:kind])
      tpl.assign_attributes(
        filename: file.original_filename, content_type: file.content_type, content: file.read
      )
      if tpl.save
        redirect_to @cost_center, notice: "Modelo de #{tpl.kind} salvo."
      else
        redirect_to @cost_center, alert: tpl.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize :letter, :manage?
      @cost_center.letter_templates.find(params[:id]).destroy
      redirect_to @cost_center, notice: "Modelo removido."
    end

    private

    def set_cost_center
      @cost_center = CostCenter.find(params[:cost_center_id])
    end
  end
end
