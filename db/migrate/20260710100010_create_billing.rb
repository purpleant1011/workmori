class CreateBilling < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.string  :code, null: false
      t.string  :name, null: false
      t.text    :description
      t.integer :monthly_price_krw, null: false, default: 0
      t.integer :monthly_price_vat_krw, null: false, default: 0
      t.jsonb   :features, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :plans, :code, unique: true

    create_table :contract_terms do |t|
      t.references :account, null: false, foreign_key: true
      t.references :plan, foreign_key: true
      t.string  :contract_code, null: false  # 고객 식별 코드 (B-2026-01 등)
      t.integer :monthly_price_krw, null: false, default: 0
      t.integer :monthly_price_vat_krw, null: false, default: 0
      t.integer :deposit_amount_krw, null: false, default: 0
      t.integer :billing_anchor_day, null: false, default: 1
      t.date    :test_started_on
      t.date    :test_ends_on
      t.date    :official_service_started_on
      t.string  :status, null: false, default: "draft"  # draft | signed | active | terminated
      t.jsonb   :price_overrides, null: false, default: {}  # 비공개 가격
      t.text    :notes
      t.timestamps
    end
    add_index :contract_terms, :contract_code, unique: true

    create_table :deposits do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contract_term, foreign_key: true
      t.integer :amount_krw, null: false
      t.string  :state, null: false, default: "received"  # received | refunded | partially_refunded
      t.date    :received_on
      t.date    :refunded_on
      t.text    :refund_bank_info_encrypted
      t.timestamps
    end

    create_table :invoices do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contract_term, foreign_key: true
      t.string  :invoice_number, null: false
      t.date    :billing_period_start, null: false
      t.date    :billing_period_end, null: false
      t.integer :supply_amount_krw, null: false, default: 0
      t.integer :vat_amount_krw, null: false, default: 0
      t.integer :total_amount_krw, null: false, default: 0
      t.integer :discount_amount_krw, null: false, default: 0
      t.integer :final_amount_krw, null: false, default: 0
      t.string  :state, null: false, default: "draft"  # draft | issued | paid | overdue | void
      t.date    :due_on
      t.date    :issued_on
      t.date    :paid_on
      t.timestamps
    end
    add_index :invoices, :invoice_number, unique: true

    create_table :payments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.string  :provider, null: false  # manual | stripe | tos_payments
      t.string  :provider_txn_id
      t.integer :amount_krw, null: false
      t.string  :state, null: false, default: "pending"  # pending | succeeded | failed | refunded
      t.datetime :paid_at
      t.text    :memo
      t.text    :encrypted_metadata
      t.timestamps
    end
  end
end
