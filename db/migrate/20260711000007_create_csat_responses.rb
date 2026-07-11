class CreateCsatResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :csat_responses do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id
      t.string :channel, null: false, default: "app"
      t.integer :score, null: false
      t.text :comment
      t.string :respondent_kind, null: false, default: "customer"
      t.timestamps
    end
    add_index :csat_responses, :account_id
    add_index :csat_responses, :conversation_id
    add_index :csat_responses, [:account_id, :created_at]
  end
end