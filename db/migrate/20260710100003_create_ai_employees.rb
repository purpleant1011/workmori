class CreateAiEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_employees do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :avatar_url
      t.string  :role_label, null: false, default: "마케팅 직원"  # 사람이 보는 직함
      t.text    :industry_expertise
      t.string  :tone, null: false, default: "calm_professional"  # calm_professional | warm_casual | bright_active
      t.integer :friendliness, null: false, default: 60  # 0..100
      t.integer :expertise_level, null: false, default: 70
      t.integer :proactiveness, null: false, default: 50
      t.string  :honorific, null: false, default: "formal"  # formal | semi | casual
      t.integer :sentence_length, null: false, default: 60  # 짧은..긴
      t.text    :vocabulary_phrases_json, null: false, default: "[]"  # 자주 쓰는 표현
      t.text    :forbidden_phrases_json, null: false, default: "[]"
      t.text    :can_answer_topics_json, null: false, default: "[]"
      t.text    :must_handoff_topics_json, null: false, default: "[]"
      t.text    :work_days_json, null: false, default: '["mon","tue","wed","thu","fri"]'
      t.text    :work_hours_json, null: false, default: '{"start":"09:00","end":"18:00"}'
      t.integer :daily_post_quota, null: false, default: 1
      t.integer :weekly_post_quota, null: false, default: 5
      t.string  :approval_mode, null: false, default: "owner_review"  # none | owner_review | staff_review
      t.text    :channel_behaviors_json, null: false, default: "{}"
      t.integer :monthly_token_budget, null: false, default: 200_000
      t.integer :daily_token_budget, null: false, default: 20_000
      t.integer :monthly_cost_budget_krw, null: false, default: 50_000
      t.integer :daily_cost_budget_krw, null: false, default: 5_000
      t.text    :natural_language_instructions
      t.text    :system_notes                  # 운영자만 보이는 내부 메모
      t.string  :status, null: false, default: "active"  # active | paused | archived
      t.timestamps
    end
    add_index :ai_employees, :status

    create_table :ai_employee_versions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text    :snapshot_json, null: false      # 시점의 전체 설정
      t.text    :change_summary
      t.references :changed_by_user, foreign_key: { to_table: :users }
      t.boolean :restored_from_previous, null: false, default: false
      t.datetime :activated_at
      t.timestamps
    end

    create_table :guardrail_policies do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, null: false, foreign_key: true
      t.string  :kind, null: false  # forbidden_phrase | forbidden_topic | must_handoff | pricing_claim
      t.string  :pattern
      t.text    :description
      t.string  :severity, null: false, default: "block"  # block | warn | handoff
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :escalation_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, foreign_key: true
      t.string  :topic, null: false   # 잔흔 | 피부 | 시술가능 | 클레임 | 가격 | 환불 | 민감사정
      t.text    :handoff_message
      t.string  :handoff_channel, null: false, default: "kakao"  # kakao | phone | email | manual
      t.text    :handoff_contact
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end
end
