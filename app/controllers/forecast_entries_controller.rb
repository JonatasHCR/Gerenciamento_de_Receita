class ForecastEntriesController < ApplicationController
  before_action :set_entry, only: [:edit, :update, :destroy]

  def index
    authorize ForecastEntry
    @month_year = if params[:month].present?
      pt_month_year(Date.parse("#{params[:month]}-01"))
    else
      params[:month_year].presence || pt_month_year
    end
    @entries_by_client = Forecasts::SummaryQuery.new(
      month_year: @month_year,
      scope: policy_scope(ForecastEntry)
    ).call
  end

  def new
    @entry = ForecastEntry.new
    authorize @entry, :new?
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
      redirect_to forecast_entries_path, notice: "Previsão atualizada."
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
    permitted = params.require(:forecast_entry).permit(
      :month_year, :forecasted_total, :forecasted_pct_ufc,
      :realized_total, :realized_pct_ufc, :observations, :cost_center_id
    )
    if permitted[:month_year].present? && permitted[:month_year].match?(/\A\d{4}-\d{2}\z/)
      permitted[:month_year] = pt_month_year(Date.parse("#{permitted[:month_year]}-01"))
    end
    permitted
  end
end
