# Criação do usuário admin — separada do seed de demonstração (db/seeds.rb).
# Uso (produção ou qualquer ambiente):
#   ADMIN_EMAIL=admin@empresa.com ADMIN_PASSWORD=senha-forte bin/rails admin:create
# No Docker de produção (as vars já vêm do .env via docker-compose.prod.yml):
#   docker compose -f docker-compose.prod.yml exec web bin/rails admin:create
namespace :admin do
  desc "Cria (ou atualiza a senha de) um usuário admin a partir de ADMIN_EMAIL/ADMIN_PASSWORD"
  task create: :environment do
    email = ENV["ADMIN_EMAIL"].presence || "admin@ufc.com.br"
    pass  = ENV["ADMIN_PASSWORD"].presence

    abort("❌ Defina ADMIN_PASSWORD (mín. 6 caracteres). ADMIN_EMAIL é opcional.") if pass.blank?

    user = User.find_or_initialize_by(email: email)
    novo = user.new_record?

    user.name = "Administrador" if user.name.blank?
    user.role = :admin
    user.password = pass
    user.save!

    # Se a conta estava travada (lockable), libera.
    user.unlock_access! if user.respond_to?(:access_locked?) && user.access_locked?

    puts "✅ Admin #{novo ? 'criado' : 'atualizado'}: #{email} (role: #{user.role})"
  end
end
