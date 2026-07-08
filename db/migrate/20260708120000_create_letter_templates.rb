class CreateLetterTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :letter_templates do |t|
      t.references :cost_center, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :filename
      t.string :content_type
      t.binary :content, null: false # bytes do .docx (modelo enviado pelo usuário)
      t.timestamps
    end
    add_index :letter_templates, [:cost_center_id, :kind], unique: true
  end
end
