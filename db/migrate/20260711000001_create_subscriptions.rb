class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.bigint :account_id, null: false
      t.bigint :plan_id, null: false
      t.bigint :contract_term_id
      t.string :state, default: "active", null: false
      t.date :started_on, null: false
      t.date :current_period_start, null: false
      t.date :current_period_end, null: false
      t.date :next_billing_on
      t.date :ended_on
      t.integer :monthly_price_krw, default: 0, null: false
      t.integer :monthly_price_vat_krw, default: 0, null: false
      t.integer :deposit_krw, default: 0, null: false
      t.boolean :auto_renew, default: true, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end
    add_index :subscriptions, :account_id
    add_index :subscriptions, :plan_id
    add_index :subscriptions, :state
  end
end
