class CreateSafetyLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :safety_logs do |t|
      t.bigint :account_id
      t.bigint :content_item_id
      t.bigint :conversation_id
      t.string :stage, null: false, default: "pre_publish"
      t.string :verdict, null: false, default: "passed"
      t.jsonb  :rules_json, default: [], null: false
      t.jsonb  :hits_json, default: [], null: false
      t.text   :notes
      t.timestamps
    end
    add_index :safety_logs, :account_id
    add_index :safety_logs, :content_item_id
    add_index :safety_logs, :stage
    add_index :safety_logs, :verdict
  end
end
