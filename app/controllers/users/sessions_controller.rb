class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, only: [:new, :create], raise: false

  # `new` renderiza a tela com o botao que POSTa para o Keycloak — nao ha mais
  # formulario de senha. `create` nao existe: quem autentica e o IdP, e o
  # retorno cai em Users::OmniauthCallbacksController.

  # Logout RP-initiated: alem de encerrar a sessao local, encerra a do Keycloak,
  # o que desloga a pessoa dos tres sistemas. Encerrar so a local deixaria o
  # proximo acesso entrar direto, sem pedir senha, e daria a impressao falsa de
  # que o logout nao funcionou.
  def destroy
    fim = url_de_logout_do_keycloak
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    redirect_to fim, allow_other_host: true
  end

  private

  def url_de_logout_do_keycloak
    host  = ENV.fetch("HOST_IP", nil)
    return portal_url if host.blank?

    porta = ENV.fetch("KEYCLOAK_PORT", "8080")
    params = { post_logout_redirect_uri: portal_url,
               client_id: ENV.fetch("OIDC_CLIENT_ID", "receita-web") }
    "http://#{host}:#{porta}/realms/ufc/protocol/openid-connect/logout?#{params.to_query}"
  end
end
