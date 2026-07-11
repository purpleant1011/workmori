class CreateReferralsAndTerminations < ActiveRecord::Migration[8.0]
  def change
    create_table :referral_links do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by_user, foreign_key: { to_table: :users }
      t.string  :code, null: false
      t.string  :target_industry_filter
      t.boolean :active, null: false, default: true
      t.datetime :expires_at
      t.timestamps
    end
    add_index :referral_links, :code, unique: true

    create_table :referrals do |t|
      t.references :referral_link, null: false, foreign_key: true
      t.references :referrer_account, null: false, foreign_key: { to_table: :accounts }
      t.string  :referred_business_name
      t.string  :referred_business_type
      t.date    :referred_contract_date
      t.string  :state, null: false, default: "lead"  # lead | contacted | contracted | expired
      t.timestamps
    end

    create_table :referral_rewards do |t|
      t.references :account, null: false, foreign_key: true
      t.references :referral, null: false, foreign_key: true
      t.integer :discount_amount_krw_per_month, null: false
      t.integer :discount_months, null: false
      t.date    :starts_on
      t.date    :ends_on
      t.string  :state, null: false, default: "pending"  # pending | active | expired | cancelled
      t.timestamps
    end

    create_table :termination_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :requested_by_user, foreign_key: { to_table: :users }
      t.date    :applied_on
      t.date    :requested_termination_on
      t.text    :reason
      t.string  :state, null: false, default: "received"  # received | processing | completed | rejected
      t.datetime :completed_at
      t.text    :revocation_checklist_json, null: false, default: "[]"  # 채널 회수 체크리스트
      t.text    :export_requested_json, null: false, default: "[]"
      t.text    :deletion_requested_json, null: false, default: "[]"
      t.timestamps
    end

    create_table :data_export_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :requested_by_user, foreign_key: { to_table: :users }
      t.string  :state, null: false, default: "pending"  # pending | processing | ready | expired | failed
      t.string  :storage_path
      t.datetime :ready_at
      t.datetime :expires_at
      t.timestamps
    end

    create_table :deletion_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :requested_by_user, foreign_key: { to_table: :users }
      t.string  :state, null: false, default: "pending"  # pending | processing | completed | failed
      t.datetime :completed_at
      t.text    :deletion_summary_json, null: false, default: "{}"
      t.timestamps
    end
  end
end
