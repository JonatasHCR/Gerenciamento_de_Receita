class RemoveRedundantIndexes < ActiveRecord::Migration[8.1]
  # Cada um destes índices de coluna única é PREFIXO de um índice composto btree
  # (mesma tabela) — o composto já atende as buscas por essa coluna e as checagens
  # de FK. São redundantes para leitura e só custam escrita/armazenamento (tabelas
  # de import: invoices, receipts, forecast_entries, user_cost_centers).
  def change
    remove_index :invoices, column: :cost_center_id,
                 name: "index_invoices_on_cost_center_id"                 # ⊂ (cost_center_id, number)
    remove_index :invoices, column: :issued_at,
                 name: "index_invoices_on_issued_at"                      # ⊂ (issued_at, cost_center_id)
    remove_index :receipts, column: :invoice_id,
                 name: "index_receipts_on_invoice_id"                     # ⊂ (invoice_id, value)
    remove_index :forecast_entries, column: :cost_center_id,
                 name: "index_forecast_entries_on_cost_center_id"         # ⊂ (cost_center_id, month_year)
    remove_index :user_cost_centers, column: :user_id,
                 name: "index_user_cost_centers_on_user_id"               # ⊂ (user_id, cost_center_id)
  end
end
