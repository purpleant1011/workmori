class CreateInquiries < ActiveRecord::Migration[8.0]
  def change
    create_table :inquiries do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :subject, null: false
      t.text   :body, null: false
      t.string :subject_kind
      t.decimal :score, precision: 4, scale: 3
      t.string :status, null: false, default: "new"
      t.boolean :consent_marketing, null: false, default: false
      t.timestamps
    end
    add_index :inquiries, :status
    add_index :inquiries, :subject_kind
  end
end
