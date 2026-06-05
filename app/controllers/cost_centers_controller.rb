class CostCentersController < ApplicationController
  before_action :set_cost_center, only: [:show, :edit, :update, :destroy]
  before_action :set_coordinator_options, only: [:new, :create, :edit, :update]

  def index
    scope = policy_scope(CostCenter).includes(:client)
    scope = scope.where("cr_code ILIKE :q OR description ILIKE :q OR coordinator ILIKE :q",
                        q: "%#{params[:q]}%") if params[:q].present?
    @cost_centers = scope.ordered
  end

  def show
    authorize @cost_center
  end

  def new
    authorize CostCenter
    @cost_center = CostCenter.new
    @cost_center.coordinator = current_user.name if current_user.coordenador?
  end

  def create
    authorize CostCenter
    @cost_center = CostCenter.new(cost_center_params)
    if @cost_center.save
      redirect_to @cost_center, notice: "Centro de custo criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @cost_center
  end

  def update
    authorize @cost_center
    if @cost_center.update(cost_center_params)
      redirect_to @cost_center, notice: "Centro de custo atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @cost_center
    if @cost_center.destroy
      redirect_to cost_centers_path, notice: "Centro de custo removido."
    else
      redirect_to @cost_center, alert: "Não é possível remover: possui notas fiscais associadas."
    end
  end

  private

  def set_cost_center
    @cost_center = CostCenter.find(params[:id])
  end

  def cost_center_params
    params.require(:cost_center).permit(:cr_code, :description, :object_text, :participation_percent, :coordinator, :end_date, :client_id)
  end

  def set_coordinator_options
    return if current_user.coordenador?
    user_names = User.where(role: [:coordenador, :gestor]).order(:name).pluck(:name)
    existing   = CostCenter.where.not(coordinator: [nil, ""]).distinct.pluck(:coordinator)
    @coordinator_options = (user_names + existing).uniq.sort
  end
end
