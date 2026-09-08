# Índices para a marca d'água da sincronização.
#
# A API de sync consulta `WHERE updated_at > ?` em cost_centers a cada 15
# minutos. Nenhuma das duas tabelas tinha índice em `updated_at` — a consulta
# faria seq scan toda vez.
#
# `clients` entra junto porque uma mudança no cliente (nome/razão social) também
# precisa chegar ao inventário, e o mesmo padrão de consulta se aplica.
class AddUpdatedAtIndexesForSync < ActiveRecord::Migration[8.1]
  def change
    add_index :cost_centers, :updated_at
    add_index :clients, :updated_at

    # As exclusões saem da tabela do PaperTrail, filtrando por tipo + evento +
    # data. O índice padrão do PaperTrail é (item_type, item_id), que não ajuda
    # nesta consulta.
    add_index :versions, [:item_type, :event, :created_at],
              name: "index_versions_on_type_event_created_at"
  end
end
