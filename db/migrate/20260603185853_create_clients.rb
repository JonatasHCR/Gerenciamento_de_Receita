class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.string :full_name, null: false, default: ""

      t.timestamps
    end

    add_index :clients, :name, unique: true
  end
end
