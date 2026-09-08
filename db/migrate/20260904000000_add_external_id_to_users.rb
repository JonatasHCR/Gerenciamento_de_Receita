# Vínculo entre a conta local e a identidade do Keycloak.
#
# `external_id` guarda o `sub` (UUID). No primeiro login o usuário é achado por
# email e este campo é gravado; daí em diante o casamento é por aqui. O id local
# nunca muda — é o que preserva o PaperTrail (`versions.whodunnit`) e os
# `user_cost_centers`.
#
# `encrypted_password` NÃO é derrubada: manter a coluna torna esta migration
# reversível sem perda, e nada mais a lê. Nenhum hash legado foi migrado — o
# reset de senha foi forçado no Keycloak.
class AddExternalIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :external_id, :string
    add_index  :users, :external_id, unique: true

    # `encrypted_password` era NOT NULL DEFAULT "". Quem for provisionado pelo
    # SSO não tem senha, então o default vazio passa a ser o normal — mas
    # deixamos a coluna nullable para não depender dele.
    change_column_null :users, :encrypted_password, true
  end
end
