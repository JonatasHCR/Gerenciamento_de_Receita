# Permite descoberta OIDC em HTTP puro.
#
# O gem `openid_connect` (e o `swd`, que ele usa para o .well-known) assume
# HTTPS: o construtor de URL padrão é `URI::HTTPS`. Com o Keycloak em
# `http://<ip>:8080` a descoberta tenta um handshake TLS contra uma porta que
# fala HTTP puro e falha com uma mensagem que não ajuda em nada:
#
#   SSL_connect ... state=SSLv3/TLS write client hello: wrong version number
#
# Não há como configurar isso por client_options — é global da biblioteca.
#
# É uma consequência direta da decisão de rodar sem TLS, e é a PRIMEIRA coisa a
# reverter no dia em que houver certificado: basta apagar este arquivo.
require "openid_connect"

# `SWD.url_builder` e o unico ponto: o
# openid_connect/discovery/provider/config/resource.rb monta a URL do
# .well-known com ele. Trocar para URI::HTTP resolve a descoberta inteira.
SWD.url_builder = URI::HTTP

# Sem isto os erros de descoberta e de troca de token saem sem contexto.
OpenIDConnect.logger = Rails.logger
