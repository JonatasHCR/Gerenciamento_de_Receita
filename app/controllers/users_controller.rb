class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :destroy]

  # Campos que vivem no Keycloak. Só podem ser escritos na criação.
  DO_KEYCLOAK = %w[name email].freeze

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
    return if recusar_dados_do_keycloak(users_path)

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
    return if recusar_dados_do_keycloak(edit_profile_path)

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

  # Recusa, e não descarta em silêncio: o strong params dropa sem avisar, e a
  # tela diria "atualizado com sucesso" sem ter mudado nada. Roda depois do
  # authorize, senão responderia antes da negação do Pundit.
  def recusar_dados_do_keycloak(destino)
    return false if (DO_KEYCLOAK & params.fetch(:user, {}).keys.map(&:to_s)).empty?

    redirect_to destino,
                alert: "Nome e e-mail vêm do Keycloak e não podem ser alterados aqui.",
                status: :see_other
    true
  end

  def user_params
    # :role só é permitido para admin — evita escalonamento de privilégio via
    # mass assignment (um não-admin nunca consegue alterar o próprio papel).
    #
    # :name e :email só na criação. Depois disso quem manda é o Keycloak, e o
    # callback de login não reescreve esses campos — editar aqui divergiria em
    # silêncio, para sempre.
    permitted = []
    permitted += [:name, :email] if action_name == "create"
    permitted << :role if current_user.admin?
    # fetch, e nao require: para quem nao e admin sobra zero campo editavel, e o
    # require levantaria ParameterMissing num submit vazio.
    params.fetch(:user, ActionController::Parameters.new).permit(*permitted)
  end

  # Só admin gerencia vínculos, e só para coordenadores (demais papéis veem tudo).
  def apply_cost_center_ids(user)
    return unless current_user.admin? && user.coordenador?
    return unless params[:user].key?(:cost_center_ids)
    user.assign_coordinated_cost_centers(params[:user][:cost_center_ids])
  end
end
