class AddActiveToCostCenters < ActiveRecord::Migration[8.1]
  def change
    add_column :cost_centers, :active, :boolean, null: false, default: true
    add_index :cost_centers, :active
  end
end
