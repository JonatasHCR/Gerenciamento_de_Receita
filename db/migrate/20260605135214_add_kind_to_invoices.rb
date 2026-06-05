class AddKindToInvoices < ActiveRecord::Migration[8.1]
  def change
    # 0 = principal, 1 = reajuste. Padrão: principal.
    add_column :invoices, :kind, :integer, default: 0, null: false
    add_index :invoices, :kind
  end
end
