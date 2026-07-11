class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, null: false, foreign_key: true
      t.references :channel_connection, foreign_key: true
      t.string  :channel_kind, null: false
      t.string  :external_thread_id
      t.string  :customer_display_name
      t.string  :state, null: false, default: "open"  # open | escalated | closed
      t.string  :risk_level, null: false, default: "low"  # low | medium | high
      t.datetime :last_message_at
      t.datetime :escalated_at
      t.timestamps
    end

    create_table :conversation_participants do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.string  :kind, null: false  # customer | ai | operator
      t.string  :display_name
      t.text    :encrypted_contact  # PII 암호화 저장
      t.boolean :remembered, null: false, default: false
      t.timestamps
    end

    create_table :messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.string  :direction, null: false  # inbound | outbound
      t.string  :author_kind, null: false  # customer | ai | operator
      t.text    :body, null: false
      t.jsonb   :redacted_body_json, null: false, default: {}  # 마스킹된 원문/매핑
      t.text    :ai_draft
      t.jsonb   :evidence_chunks_json, null: false, default: "[]"
      t.string  :state, null: false, default: "received"  # received | drafted | sent | escalated | failed
      t.text    :error_message
      t.datetime :redacted_at
      t.timestamps
    end

    create_table :handoffs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :message, foreign_key: true
      t.string  :reason, null: false  # 잔흔 | 피부 | 시술가능 | 클레임 | 가격 | 환불 | 민감 | low_confidence | explicit_request
      t.text    :summary
      t.string  :channel, null: false  # kakao | phone | email | manual
      t.string  :state, null: false, default: "open"  # open | acknowledged | resolved | abandoned
      t.references :assigned_to_user, foreign_key: { to_table: :users }
      t.datetime :acknowledged_at
      t.datetime :resolved_at
      t.text    :resolution_notes
      t.timestamps
    end
  end
end
