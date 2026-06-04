class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :receipts do |t|
      t.date :payment_date, null: false
      t.decimal :value, precision: 15, scale: 2, null: false
      t.text :observations
      t.references :invoice, null: false, foreign_key: true

      t.timestamps
    end

    add_index :receipts, :payment_date
  end
end
