class CreateContentStudio < ActiveRecord::Migration[8.0]
  def change
    create_table :content_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, null: false, foreign_key: true
      t.bigint  :automation_rule_id  # FK는 자동화 마이그레이션에서 추가
      t.string  :title, null: false
      t.text    :body
      t.text    :caption
      t.text    :hashtags_json, null: false, default: "[]"
      t.string  :content_kind, null: false, default: "feed"  # feed | reel_script | blog | thread | place_post | daangn_post | cardnews | shortform
      t.string  :state, null: false, default: "draft"  # draft | generated | needs_review | approved | scheduled | published | failed | archived
      t.string  :safety_state, null: false, default: "unchecked"  # unchecked | passed | needs_review | blocked
      t.jsonb   :safety_notes, null: false, default: []
      t.text    :evidence_chunks_json, null: false, default: "[]"  # 근거
      t.string  :target_channel_kind
      t.references :target_channel_connection, foreign_key: { to_table: :channel_connections }
      t.datetime :scheduled_at
      t.datetime :published_at
      t.text    :published_external_url
      t.timestamps
    end
    add_index :content_items, :scheduled_at

    create_table :content_versions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :content_item, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text    :body
      t.text    :caption
      t.text    :hashtags_json, null: false, default: "[]"
      t.jsonb   :diff_from_previous, null: false, default: {}
      t.references :changed_by_user, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :media_assets do |t|
      t.references :account, null: false, foreign_key: true
      t.references :content_item, foreign_key: true
      t.string  :kind, null: false  # photo | video | audio | doc
      t.string  :filename, null: false
      t.string  :storage_path
      t.string  :checksum_sha256
      t.text    :description
      t.boolean :contains_personal_data, null: false, default: false
      t.boolean :ai_training_allowed, null: false, default: false
      t.string  :consent_status, null: false, default: "unknown"  # unknown | granted | denied | pending
      t.text    :consent_notes
      t.timestamps
    end

    create_table :publication_attempts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :content_item, null: false, foreign_key: true
      t.references :channel_connection, null: false, foreign_key: true
      t.string  :idempotency_key, null: false
      t.string  :state, null: false, default: "pending"  # pending | publishing | succeeded | failed | cancelled
      t.integer :attempts, null: false, default: 0
      t.text    :error_message
      t.text    :external_url
      t.text    :external_id
      t.jsonb   :request_payload, null: false, default: {}
      t.jsonb   :response_payload, null: false, default: {}
      t.timestamps
    end
    add_index :publication_attempts, :idempotency_key, unique: true
  end
end
