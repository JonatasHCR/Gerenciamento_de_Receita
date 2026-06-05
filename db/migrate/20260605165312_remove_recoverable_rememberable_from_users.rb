class RemoveRecoverableRememberableFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_index  :users, :reset_password_token, if_exists: true
    remove_column :users, :reset_password_token,   :string
    remove_column :users, :reset_password_sent_at, :datetime
    remove_column :users, :remember_created_at,    :datetime
  end

  def down
    add_column :users, :reset_password_token,   :string
    add_column :users, :reset_password_sent_at, :datetime
    add_column :users, :remember_created_at,    :datetime
    add_index  :users, :reset_password_token, unique: true
  end
end
