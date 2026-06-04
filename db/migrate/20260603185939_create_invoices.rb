class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.string :number, null: false
      t.string :client_name, null: false, default: ""
      t.date :issued_at, null: false
      t.decimal :value, precision: 15, scale: 2, null: false
      t.text :observations
      t.references :cost_center, null: false, foreign_key: true

      t.timestamps
    end

    add_index :invoices, :issued_at
    add_index :invoices, [:cost_center_id, :number], unique: true
  end
end
