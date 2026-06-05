class AddTrigramIndexToInvoicesNumber < ActiveRecord::Migration[8.1]
  # Busca dinâmica por número da NF usa `number ILIKE '%termo%'` (wildcard à
  # esquerda), que não aproveita o índice btree. O índice GIN trigram acelera
  # essa busca — mesmo padrão já usado em cost_centers (cr_code/description).
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :invoices, :number,
              name: "idx_invoices_number_trgm",
              opclass: :gin_trgm_ops,
              using: :gin
  end
end
