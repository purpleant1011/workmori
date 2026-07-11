class CreateBusinessProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :business_profiles do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :legal_name, null: false
      t.string  :trade_name
      t.string  :industry_code, null: false, default: "other"  # beauty | nail | skin | waxing | brow | lash | scalp | other
      t.string  :industry_subcategory
      t.string  :owner_name
      t.string  :business_registration_number
      t.string  :phone
      t.string  :public_email
      t.text    :address
      t.string  :region_label    # 자유 텍스트 ("청라", "강남", ...)
      t.text    :business_hours_json, null: false, default: "{}"  # {mon: [{open:"10:00", close:"20:00"}], ...}
      t.text    :holidays_json, null: false, default: "[]"
      t.text    :timezone, null: false, default: "Asia/Seoul"
      t.text    :brand_intro
      t.text    :products_json, null: false, default: "[]"
      t.text    :services_json, null: false, default: "[]"
      t.text    :faqs_json, null: false, default: "[]"
      t.text    :customer_anxieties_json, null: false, default: "[]"
      t.text    :target_audience
      t.text    :differentiators
      t.text    :forbidden_phrases_json, null: false, default: "[]"  # 자유 금칙어
      t.text    :forbidden_topics_json, null: false, default: "[]"
      t.text    :escalation_rules_json, null: false, default: "[]"  # 사람연결 규칙
      t.text    :preferred_channels_json, null: false, default: "[]"
      t.integer :onboarding_step, null: false, default: 0
      t.boolean :onboarding_complete, null: false, default: false
      t.boolean :operator_managed, null: false, default: false
      t.timestamps
    end
    add_index :business_profiles, :industry_code
  end
end
