class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :destroy]

  def index
    authorize User
    @users = policy_scope(User).order(:name)
  end

  def new
    authorize User
    @user = User.new
  end

  def create
    authorize User
    @user = User.new(user_params)
    if @user.save
      apply_cost_center_ids(@user)
      redirect_to users_path, notice: "Usuário criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user
    if @user.update(user_params)
      apply_cost_center_ids(@user)
      redirect_to users_path, notice: "Usuário atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @user
    @user.destroy
    redirect_to users_path, notice: "Usuário removido."
  end

  def profile_edit
    @user = current_user
    @is_profile = true
    authorize @user, :update?
    render :edit
  end

  def profile_update
    @user = current_user
    @is_profile = true
    authorize @user, :update?
    if @user.update(user_params)
      redirect_to edit_profile_path, notice: "Perfil atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    # :role só é permitido para admin — evita escalonamento de privilégio via
    # mass assignment (um não-admin nunca consegue alterar o próprio papel).
    #
    # :password e :password_confirmation saíram: este sistema não guarda mais
    # senha. Trocar a senha é no Account Console do Keycloak, e ela vale para os
    # três sistemas. O `build_update_params`, que existia só para descartar a
    # senha em branco no update, foi junto.
    permitted = [:name, :email]
    permitted << :role if current_user.admin?
    params.require(:user).permit(*permitted)
  end

  # Só admin gerencia vínculos, e só para coordenadores (demais papéis veem tudo).
  def apply_cost_center_ids(user)
    return unless current_user.admin? && user.coordenador?
    return unless params[:user].key?(:cost_center_ids)
    user.assign_coordinated_cost_centers(params[:user][:cost_center_ids])
  end
end
