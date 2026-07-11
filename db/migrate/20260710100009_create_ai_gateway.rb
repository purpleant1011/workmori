class CreateAiGateway < ActiveRecord::Migration[8.0]
  def change
    create_table :model_catalog_entries do |t|
      t.string  :code, null: false                  # m3 | gpt-4o | gpt-image-1 등
      t.string  :provider, null: false             # minimax | openai | anthropic | gemini | stub
      t.string  :kind, null: false                 # text | image | embedding
      t.string  :display_name
      t.text    :description
      t.string  :api_model_name                    # 공급자 측 실제 식별자
      t.integer :context_window
      t.integer :max_output_tokens
      t.integer :input_price_per_1k_krw, null: false, default: 0
      t.integer :output_price_per_1k_krw, null: false, default: 0
      t.integer :image_price_per_unit_krw, null: false, default: 0
      t.boolean :training_opt_out, null: false, default: true
      t.string  :data_residency_region
      t.boolean :active, null: false, default: true
      t.jsonb   :capabilities, null: false, default: {}
      t.timestamps
    end
    add_index :model_catalog_entries, :code, unique: true

    create_table :model_policies do |t|
      t.references :account, foreign_key: true  # null = 전역
      t.string  :purpose, null: false  # text_default | text_premium | image_default | image_premium | embedding
      t.string  :primary_code, null: false
      t.string  :fallback_code
      t.integer :daily_token_cap, null: false, default: 100_000
      t.integer :monthly_token_cap, null: false, default: 2_000_000
      t.integer :daily_cost_cap_krw, null: false, default: 10_000
      t.integer :monthly_cost_cap_krw, null: false, default: 200_000
      t.text    :masking_rules_json, null: false, default: "[]"  # PII 마스킹 규칙
      t.timestamps
    end

    create_table :usage_records do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, foreign_key: true
      t.references :automation_execution, foreign_key: true
      t.references :content_item, foreign_key: true
      t.references :message, foreign_key: true
      t.string  :purpose, null: false
      t.string  :model_code, null: false
      t.string  :provider, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :image_count, null: false, default: 0
      t.integer :cost_krw, null: false, default: 0
      t.integer :latency_ms, null: false, default: 0
      t.string  :result_state, null: false, default: "ok"  # ok | fallback | failed
      t.text    :error_class
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    create_table :budgets do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :scope, null: false  # account | ai_employee | daily | monthly
      t.string  :metric, null: false  # tokens | cost_krw | image_count
      t.integer :limit_value, null: false
      t.integer :warn_at_percent, null: false, default: 80
      t.integer :current_value, null: false, default: 0
      t.datetime :period_start
      t.datetime :period_end
      t.timestamps
    end
  end
end
