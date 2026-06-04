class CreateUserCostCenters < ActiveRecord::Migration[8.1]
  def change
    create_table :user_cost_centers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :cost_center, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_cost_centers, [:user_id, :cost_center_id], unique: true
  end
end
