class CreateCostCenters < ActiveRecord::Migration[8.1]
  def change
    create_table :cost_centers do |t|
      t.string :cr_code, null: false
      t.string :description, null: false, default: ""
      t.text :object_text
      t.decimal :participation, precision: 5, scale: 4, default: "1.0"
      t.string :coordinator
      t.date :end_date
      t.references :client, null: false, foreign_key: true

      t.timestamps
    end

    add_index :cost_centers, :cr_code, unique: true
  end
end
