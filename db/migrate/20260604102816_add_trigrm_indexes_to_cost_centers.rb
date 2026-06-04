class AddTrigrmIndexesToCostCenters < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    add_index :cost_centers, :description, using: :gin,
              opclass: :gin_trgm_ops, name: "idx_cost_centers_description_trgm"
    add_index :cost_centers, :coordinator, using: :gin,
              opclass: :gin_trgm_ops, name: "idx_cost_centers_coordinator_trgm"
    add_index :cost_centers, :cr_code, using: :gin,
              opclass: :gin_trgm_ops, name: "idx_cost_centers_cr_code_trgm"
  end
end
