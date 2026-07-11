class CreateDeliveryLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false, default: "campaign"
      t.string :subject, null: false, default: ""
      t.text :body_excerpt
      t.integer :recipient_count, null: false, default: 0
      t.datetime :delivered_at
      t.string :external_provider
      t.jsonb :result_payload
      t.timestamps
    end
    add_index :delivery_logs, [:account_id, :kind, :delivered_at]
  end
end
