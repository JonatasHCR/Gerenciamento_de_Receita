class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :reconferir_grupo
  before_action :set_paper_trail_whodunnit

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  PT_MONTHS = %w[JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO].freeze

  def pt_month_year(date = Date.current)
    "#{PT_MONTHS[date.month - 1]}/#{date.year}"
  end
  helper_method :pt_month_year

  # Converte "AAAA-MM" (input month_field) em Date no 1º dia do mês.
  # Entrada ausente/inválida cai no fallback — evita 500 por Date::Error.
  def parse_month(value, fallback = Date.current.beginning_of_month)
    return fallback if value.blank?
    Date.strptime(value.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, Date::Error
    fallback
  end

  # Converte "AAAA-MM-DD" (input date_field) em Date. Nil/inválido → fallback.
  def parse_date(value, fallback = nil)
    return fallback if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError, Date::Error
    fallback
  end

  # "06/2026" → "Jun/2026" em português abreviado para os gráficos
  def pt_month_label(mm_yyyy)
    parts = mm_yyyy.split("/")
    abbrev = PT_MONTHS[parts[0].to_i - 1].capitalize.first(3)
    "#{abbrev}/#{parts[1]}"
  end
  helper_method :pt_month_label

  def set_paper_trail_whodunnit
    PaperTrail.request.whodunnit = current_user&.id&.to_s
  end

  GRUPO_EXIGIDO = "/apps/receita".freeze

  # Sem isto, tirar alguém do grupo só valeria no próximo login.
  def reconferir_grupo
    return unless user_signed_in?
    return unless token_perto_de_vencer?

    resultado = Keycloak::Revalidacao.renovar(session[:refresh_token])

    unless resultado.ok
      # Sem resposta do Keycloak não dá para afirmar que ela ainda tem acesso.
      encerrar_sessao("Sua sessão expirou. Entre de novo.")
      return
    end

    session[:grupos] = resultado.grupos
    session[:refresh_token] = resultado.refresh_token
    session[:token_expira_em] = resultado.expira_em

    return if conta_mestra? || resultado.grupos.include?(GRUPO_EXIGIDO)

    # Nunca apaga: user_cost_centers e PaperTrail apontam para a conta.
    current_user.update_column(:ativo, false)
    encerrar_sessao("Seu acesso ao sistema de receitas foi removido.")
  end

  def token_perto_de_vencer?
    vencimento = session[:token_expira_em]
    return false if vencimento.blank?

    vencimento.to_i - Keycloak::Revalidacao::MARGEM <= Time.current.to_i
  end

  def conta_mestra?
    mestre = ENV["ADMIN_MESTRE_EMAIL"].to_s.strip.downcase
    mestre.present? && current_user.email.to_s.strip.downcase == mestre
  end

  def encerrar_sessao(mensagem)
    sign_out(current_user)
    reset_session
    redirect_to new_user_session_path, alert: mensagem
  end

  def user_not_authorized
    flash[:alert] = "Você não tem permissão para realizar esta ação."
    redirect_back_or_to root_path
  end

  # URLs do SSO. Ficam aqui, e nao num helper, porque os controllers tambem
  # precisam delas (o callback redireciona ao portal, o logout ao Keycloak) —
  # e `helpers.x` a partir de um controller nao alcanca metodos de helper.
  helper_method :portal_url, :keycloak_account_url

  def portal_url
    "http://#{ENV.fetch('HOST_IP', 'localhost')}:#{ENV.fetch('PORTAL_PORT', '3080')}"
  end

  def keycloak_account_url
    host = ENV.fetch("HOST_IP", "localhost")
    "http://#{host}:#{ENV.fetch('KEYCLOAK_PORT', '8080')}/realms/ufc/account"
  end

  # Para onde mais esta pessoa pode ir. Alimenta o seletor "Sistemas" no menu.
  #
  # Com SSO ela entra uma vez e circula entre tres aplicacoes — mas cada uma e um
  # deploy separado. Sem isto, sair daqui para outra exige lembrar a porta.
  helper_method :outros_sistemas

  def outros_sistemas
    host = "http://#{ENV.fetch('HOST_IP', 'localhost')}"
    grupos = Array(session[:grupos])

    [
      { grupo: "/apps/inventario", nome: "Inventario",
        url: "#{host}:#{ENV.fetch('INVENTARIO_PORT', '3030')}" },
      { grupo: "/apps/despesa", nome: "Radar",
        url: "#{host}:#{ENV.fetch('DESPESA_PORT', '3010')}" },
      { grupo: "/apps/controle-despesa", nome: "Controle de Despesa",
        url: "#{host}:#{ENV.fetch('CONTROLE_DESPESA_PORT', '3050')}" }
    ].select { |s| grupos.include?(s[:grupo]) }
  end
end
