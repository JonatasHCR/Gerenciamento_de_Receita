class ForecastEntriesController < ApplicationController
  before_action :set_entry, only: [:edit, :update, :destroy]

  def index
    authorize ForecastEntry
    @month_year = params[:month_year] || pt_month_year
    @entries_by_client = Forecasts::SummaryQuery.new(
      month_year: @month_year,
      scope: policy_scope(ForecastEntry)
    ).call
  end

  def new
    authorize ForecastEntry
    @entry = ForecastEntry.new
  end

  def create
    @entry = ForecastEntry.new(entry_params)
    authorize @entry
    if @entry.save
      redirect_to forecast_entries_path, notice: "Previsão criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @entry
  end

  def update
    authorize @entry
    if @entry.update(entry_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to forecast_entries_path, notice: "Previsão atualizada." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @entry
    @entry.destroy
    redirect_to forecast_entries_path, notice: "Previsão removida."
  end

  private

  def set_entry
    @entry = ForecastEntry.find(params[:id])
  end

  def entry_params
    params.require(:forecast_entry).permit(
      :month_year, :forecasted_total, :forecasted_pct_ufc,
      :realized_total, :realized_pct_ufc, :observations, :cost_center_id
    )
  end
end
