class InstallPaperTrail < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.jsonb    :object
      t.jsonb    :object_changes
      t.datetime :created_at
    end

    add_index :versions, %i[item_type item_id]
    add_index :versions, :whodunnit
    add_index :versions, :created_at
  end
end
