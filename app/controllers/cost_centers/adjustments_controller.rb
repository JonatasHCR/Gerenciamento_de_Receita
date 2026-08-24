module CostCenters
  class AdjustmentsController < ApplicationController
    before_action :set_adjustment, only: [:edit, :update, :destroy]

    def create
      @cost_center = CostCenter.find(params[:cost_center_id])
      @adjustment = @cost_center.adjustments.new(adjustment_params)
      authorize @adjustment

      if @adjustment.save
        redirect_to @cost_center, notice: "Reajuste registrado com sucesso."
      else
        redirect_to @cost_center, alert: @adjustment.errors.full_messages.to_sentence
      end
    end

    def edit
      @adjustment.amount = @adjustment.value_delta if @adjustment.valor?
    end

    def update
      if @adjustment.update(adjustment_params.except(:kind))
        redirect_to @cost_center, notice: "Reajuste atualizado com sucesso."
      else
        flash.now[:alert] = @adjustment.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      kind = @adjustment.valor? ? "o valor" : "a data final"
      @adjustment.destroy
      redirect_to @cost_center, notice: "Reajuste excluído — #{kind} do contrato foi revertido."
    end

    private

    def set_adjustment
      @adjustment = Adjustment.find(params[:id])
      authorize @adjustment
      @cost_center = @adjustment.cost_center
    end

    def adjustment_params
      params.require(:adjustment).permit(:kind, :amount, :new_value, :new_date, :note)
    end
  end
end
