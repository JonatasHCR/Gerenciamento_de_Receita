class CreateLetters < ActiveRecord::Migration[8.1]
  def change
    create_table :letters do |t|
      t.references :cost_center, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.integer :year, null: false
      t.integer :sequence, null: false
      t.string :number, null: false # nº do ofício: CA-{CR}-{sequência}/{ano}
      t.timestamps
    end
    # Sequência por CR reiniciada a cada ano; o índice único garante numeração sem colisão.
    add_index :letters, [:cost_center_id, :year, :sequence], unique: true
  end
end
