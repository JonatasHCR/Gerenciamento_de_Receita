# Be sure to restart your server when you modify this file.
# Política de segurança de conteúdo (CSP) — defesa em profundidade contra XSS/injeção.
# Ver: https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Notas de compatibilidade deste app:
# - script-src usa NONCE (sem unsafe-inline). O importmap (javascript_importmap_tags)
#   e o Chartkick (que lê content_security_policy_nonce) aplicam o nonce sozinhos;
#   o único <script> inline (anti-FOUC do tema, no layout) recebe o nonce manualmente.
# - style-src permite unsafe-inline: o Tailwind é carregado como arquivo (:self), mas o
#   Chartkick injeta um <div style="..."> de "Loading" e atributos style inline não são
#   cobertos por nonce. Sem isso, esses estilos quebrariam.
# - connect-src inclui :self (suficiente; charts/JS não chamam domínios externos).
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
    policy.form_action     :self
    policy.frame_ancestors :self
  end

  # Nonce por sessão: aleatório, estável dentro da sessão (compatível com Turbo/cache de
  # fragmento) e NUNCA vazio. Um `session.id` vazio (ex.: página de login sem sessão) gerava
  # `'nonce-'` inválido → o navegador ignorava a diretiva e bloqueava TODO script inline.
  config.content_security_policy_nonce_generator  = ->(request) {
    request.session[:csp_nonce] ||= SecureRandom.base64(16)
  }
  # Aplica o nonce apenas a script-src (style-src continua usando unsafe-inline).
  config.content_security_policy_nonce_directives = %w[script-src]
end
