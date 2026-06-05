module CostCenters
  class AdjustmentsController < ApplicationController
    def create
      @cost_center = CostCenter.find(params[:cost_center_id])
      authorize @cost_center, :update?

      @adjustment = @cost_center.adjustments.new(adjustment_params)
      if @adjustment.save
        redirect_to @cost_center, notice: "Reajuste registrado com sucesso."
      else
        redirect_to @cost_center, alert: @adjustment.errors.full_messages.to_sentence
      end
    end

    private

    def adjustment_params
      params.require(:adjustment).permit(:kind, :new_value, :new_date, :note)
    end
  end
end
