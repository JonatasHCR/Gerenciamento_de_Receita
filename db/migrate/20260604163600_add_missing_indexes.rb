class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    # Covering index para a subquery do with_open_balance:
    #   SELECT invoice_id, SUM(value) FROM receipts GROUP BY invoice_id
    # Permite index-only scan — sem acessar a heap por value.
    add_index :receipts, [:invoice_id, :value],
              name: "index_receipts_on_invoice_id_and_value"

    # Composite para queries de billing do dashboard:
    #   WHERE issued_at BETWEEN ? AND ? GROUP BY cost_center_id
    # Substitui dois index scans separados por um único.
    add_index :invoices, [:issued_at, :cost_center_id],
              name: "index_invoices_on_issued_at_and_cost_center_id"

    # Dropdown de coordenadores: User.where(role: [:coordenador, :gestor])
    add_index :users, :role,
              name: "index_users_on_role"

    # Filtro de auditoria por tipo de evento
    add_index :versions, :event,
              name: "index_versions_on_event"
  end
end
