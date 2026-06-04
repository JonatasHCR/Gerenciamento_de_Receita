class CreateForecastEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :forecast_entries do |t|
      t.string :month_year, null: false
      t.decimal :forecasted_total, precision: 15, scale: 2, default: "0"
      t.decimal :forecasted_pct_ufc, precision: 15, scale: 2, default: "0"
      t.decimal :realized_total, precision: 15, scale: 2, default: "0"
      t.decimal :realized_pct_ufc, precision: 15, scale: 2, default: "0"
      t.text :observations
      t.references :cost_center, null: false, foreign_key: true

      t.timestamps
    end

    add_index :forecast_entries, [:cost_center_id, :month_year], unique: true
  end
end
