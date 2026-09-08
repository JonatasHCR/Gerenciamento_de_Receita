# Garante que alguem tenha o papel de admin na receita.
#
# Com o SSO, esta task deixou de definir senha: quem guarda credencial e o
# Keycloak. O que ela faz e o outro lado da moeda — o **papel** dentro do
# sistema, que continua local (`users.role`).
#
# A pessoa precisa existir nos DOIS lugares:
#   1. no Keycloak, no grupo /apps/receita  -> decide se ela PODE ENTRAR
#   2. aqui, com role: :admin               -> decide o que ela PODE FAZER
#
# O vinculo entre os dois e feito sozinho no primeiro login, casando por email
# e gravando o `external_id`.
#
# Uso:
#   ADMIN_EMAIL=admin@empresa.com bin/rails admin:create
#   docker compose exec web bin/rails admin:create
namespace :admin do
  desc "Cria (ou promove) um usuario admin a partir de ADMIN_EMAIL"
  task create: :environment do
    email = ENV["ADMIN_EMAIL"].presence || "admin@ufc.com.br"

    user = User.find_or_initialize_by(email: email)
    novo = user.new_record?

    user.name = "Administrador" if user.name.blank?
    user.role = :admin
    user.save!

    puts "OK Admin #{novo ? 'criado' : 'promovido'}: #{email} (role: #{user.role})"
    puts
    puts "Falta o outro lado: no Keycloak, confira que este email existe no"
    puts "realm `ufc` e pertence ao grupo /apps/receita. Sem isso a pessoa nao"
    puts "consegue entrar — o papel local so vale depois de autenticar."
  end
end
