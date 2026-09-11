class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, only: [:new, :create], raise: false

  # `new` renderiza a tela com o botao que POSTa para o Keycloak — nao ha mais
  # formulario de senha. `create` nao existe: quem autentica e o IdP, e o
  # retorno cai em Users::OmniauthCallbacksController.

  # Delega ao portal: so ele guarda o id_token, e sem id_token_hint o Keycloak
  # pergunta antes de deslogar.
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    redirect_to "#{portal_url}/api/auth/logout", allow_other_host: true
  end
end
