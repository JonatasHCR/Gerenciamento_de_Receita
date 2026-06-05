class AddContractFieldsToCostCenters < ActiveRecord::Migration[8.1]
  def change
    add_column :cost_centers, :start_date, :date
    add_column :cost_centers, :contract_number, :string
    add_column :cost_centers, :value, :decimal, precision: 15, scale: 2, default: "0.0"
  end
end
