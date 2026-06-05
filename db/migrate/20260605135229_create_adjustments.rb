class CreateAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :adjustments do |t|
      t.references :cost_center, null: false, foreign_key: true
      t.integer :kind, null: false          # 0 = valor, 1 = prazo
      t.decimal :previous_value, precision: 15, scale: 2
      t.decimal :new_value,      precision: 15, scale: 2
      t.date    :previous_date
      t.date    :new_date
      t.text    :note
      t.timestamps
    end
  end
end
