# Content Security Policy.
#
# Ver https://guides.rubyonrails.org/security.html#content-security-policy-header

# Origens externas que o SSO exige. Vêm do ambiente pelo mesmo motivo que o
# resto: o IP e as portas são configuração, não constante de código.
def self.origem(porta_env, porta_padrao)
  host = ENV.fetch("HOST_IP", nil)
  return nil if host.blank?

  "http://#{host}:#{ENV.fetch(porta_env, porta_padrao)}"
end

KEYCLOAK_ORIGEM = origem("KEYCLOAK_PORT", "8080")
PORTAL_ORIGEM   = origem("PORTAL_PORT", "3080")

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.font_src        :self, :data
    policy.img_src         :self, :data
    policy.object_src      :none
    policy.script_src      :self
    policy.style_src       :self, :unsafe_inline
    policy.connect_src     :self
    policy.base_uri        :self

    # `form_action` precisa listar o Keycloak.
    #
    # O botão "Entrar" faz um POST para /users/auth/keycloak (que é `self`), e o
    # Rails responde com um 302 para o Keycloak. O navegador aplica
    # `form-action` TAMBÉM ao destino do redirect — então, com apenas `self`,
    # ele bloqueia a ida ao Keycloak e o clique simplesmente não faz nada. Sem
    # erro na tela: só uma violação de CSP no console.
    #
    # Vale igual para o "Confirmar identidade" da tela de manutenção, que refaz
    # o login com prompt=login, e para o logout, que termina no portal.
    policy.form_action(*[:self, KEYCLOAK_ORIGEM, PORTAL_ORIGEM].compact)

    policy.frame_ancestors :self
  end

  config.content_security_policy_nonce_generator = ->(request) {
    request.session[:csp_nonce] ||= SecureRandom.base64(16)
  }
  config.content_security_policy_nonce_directives = %w[script-src]
end
