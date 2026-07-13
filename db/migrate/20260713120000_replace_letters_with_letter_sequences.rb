class ReplaceLettersWithLetterSequences < ActiveRecord::Migration[8.1]
  def up
    create_table :letter_sequences do |t|
      t.references :cost_center, null: false, foreign_key: true, index: false
      t.integer :year, null: false
      t.integer :last_sequence, null: false, default: 0
      t.timestamps
    end
    add_index :letter_sequences, [:cost_center_id, :year], unique: true

    return unless table_exists?(:letters)

    execute <<~SQL.squish
      INSERT INTO letter_sequences (cost_center_id, year, last_sequence, created_at, updated_at)
      SELECT cost_center_id, year, MAX(sequence), NOW(), NOW()
      FROM letters GROUP BY cost_center_id, year
    SQL
    drop_table :letters
  end

  def down
    create_table :letters do |t|
      t.references :cost_center, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.integer :year, null: false
      t.integer :sequence, null: false
      t.string :number, null: false
      t.timestamps
    end
    add_index :letters, [:cost_center_id, :year, :sequence], unique: true

    drop_table :letter_sequences
  end
end
