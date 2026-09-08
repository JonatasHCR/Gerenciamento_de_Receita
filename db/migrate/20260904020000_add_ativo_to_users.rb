# Marca de acesso: users.ativo
#
# Espelha o grupo do Keycloak dentro do sistema. Quem perde o acesso fica
# `ativo = false` — a linha NÃO é removida, porque há `user_cost_centers` e o
# `whodunnit` do PaperTrail apontando para ela, e porque o histórico de quem fez
# o quê precisa continuar legível.
#
# Todo mundo que já existe entra como ativo; quem tiver perdido o acesso será
# marcado no próximo login.
class AddAtivoToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ativo, :boolean, null: false, default: true
    add_index  :users, :ativo
  end
end
