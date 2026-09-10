class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # O Keycloak devolve o usuário aqui depois do login: checa o grupo, resolve a
  # conta local e provisiona quem ainda não tem uma.
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :verify_authenticity_token, only: :keycloak

  GRUPO_EXIGIDO = "/apps/receita".freeze

  # A conta mestra: UM email do infra/.env, admin nos três sistemas ao mesmo
  # tempo. Não é grupo nem papel do Keycloak. Vazio = não existe.
  ADMIN_MESTRE = ENV["ADMIN_MESTRE_EMAIL"].to_s.strip.downcase.freeze

  def keycloak
    auth = request.env["omniauth.auth"]

    # A mestra entra sem grupo: se dependesse, tirar a si mesmo de um grupo
    # trancaria a porta de quem conserta.
    unless conta_mestra?(auth) || pertence_ao_grupo?(auth)
      # Espelha o acesso: perdeu o grupo, fica inativa. Nunca apagada — há
      # `user_cost_centers` e o PaperTrail apontando para ela.
      desativar_conta_local(auth)

      # Autenticou, só não tem acesso a ESTE sistema: no portal ela vê o que
      # pode acessar.
      redirect_to portal_url, allow_other_host: true,
        alert: "Você não tem acesso ao sistema de receitas."
      return
    end

    user = resolver_usuario(auth)

    if user.persisted?
      # A cada login, para trocar o ADMIN_MESTRE_EMAIL valer sem
      # `rails admin:create`.
      user.update!(role: :admin) if conta_mestra?(auth) && !user.admin?

      # Quando a pessoa DIGITOU a senha, não quando o token foi emitido: é o
      # que permite ao MaintenanceController exigir autenticação recente.
      session[:auth_time] = (auth.dig(:extra, :raw_info, :auth_time) || Time.current.to_i).to_i
      # Para o seletor "Sistemas" saber o que oferecer.
      session[:grupos] = Array(auth.dig(:extra, :raw_info, :groups))

      # O access token não é guardado: 1,4 KB contra os 660 B do refresh.
      session[:refresh_token] = auth.dig(:credentials, :refresh_token)
      session[:token_expira_em] =
        auth.dig(:credentials, :expires_at) || (Time.current.to_i + 300)

      destino = session.delete(:apos_reautenticacao)
      if destino.present?
        sign_in(user, event: :authentication)
        redirect_to destino, notice: "Identidade confirmada."
        return
      end

      sign_in_and_redirect user, event: :authentication
      set_flash_message!(:notice, :success, kind: "Keycloak")
    else
      redirect_to new_user_session_path,
        alert: "Não foi possível entrar: #{user.errors.full_messages.to_sentence}"
    end
  end

  def failure
    redirect_to new_user_session_path,
      alert: "Não foi possível concluir o login. Tente novamente."
  end

  private

  def pertence_ao_grupo?(auth)
    grupos = auth.dig(:extra, :raw_info, :groups) || []
    Array(grupos).include?(GRUPO_EXIGIDO)
  end

  def conta_mestra?(auth)
    ADMIN_MESTRE.present? &&
      auth.info.email.to_s.strip.downcase == ADMIN_MESTRE
  end

  def desativar_conta_local(auth)
    conta = User.find_by(external_id: auth.uid.to_s) ||
            User.find_by("LOWER(email) = ?", auth.info.email.to_s.strip.downcase)
    conta&.update_column(:ativo, false)
  end

  # `external_id` → email → cria. O casamento por email roda uma vez só, no
  # primeiro login de quem já tinha conta, e preserva o id.
  def resolver_usuario(auth)
    sub   = auth.uid.to_s
    email = auth.info.email.to_s.strip.downcase

    user = User.find_by(external_id: sub)
    if user
      # Recuperou o acesso: volta a ativa sozinha.
      user.update_column(:ativo, true) unless user.ativo?
      return user
    end

    user = User.find_by("LOWER(email) = ?", email)
    if user
      user.update!(external_id: sub, ativo: true)
      return user
    end

    User.create(
      external_id: sub,
      email: email,
      name: auth.info.name.presence || email,
      # Menor privilégio: o grupo do Keycloak diz só se pode ENTRAR.
      role: :coordenador
    )
  end
end
