class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :destroy]

  def index
    authorize User
    @users = User.order(:name)
  end

  def new
    authorize User
    @user = User.new
  end

  def create
    authorize User
    @user = User.new(user_params)
    if @user.save
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
    if @user.update(build_update_params)
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
    if @user.update(build_update_params)
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
    permitted = [:name, :email, :password, :password_confirmation]
    permitted << :role if current_user.admin?
    params.require(:user).permit(*permitted)
  end

  def build_update_params
    p = user_params
    p[:password].blank? ? p.except(:password, :password_confirmation) : p
  end
end
