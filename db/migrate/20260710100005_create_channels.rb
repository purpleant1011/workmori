class CreateChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, foreign_key: true
      t.string  :kind, null: false  # discord | instagram | threads | blog | naver_place | daangn | kakao_channel
      t.string  :handle
      t.string  :external_id
      t.text    :encrypted_token            # Active Record Encryption
      t.string  :status, null: false, default: "planned"  # planned | ready | active | paused | revoked | error
      t.text    :scopes_json, null: false, default: "[]"  # 허용 채널 ID 목록
      t.text    :error_message
      t.string  :connected_by_kind, null: false, default: "owner"  # owner | operator | staff
      t.references :connected_by_user, foreign_key: { to_table: :users }
      t.datetime :last_verified_at
      t.timestamps
    end

    create_table :channel_scopes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :channel_connection, null: false, foreign_key: true
      t.string  :scope, null: false  # 채널/서버/게시판 ID
      t.string  :label
      t.boolean :publish_allowed, null: false, default: false
      t.boolean :read_allowed, null: false, default: true
      t.timestamps
    end
  end
end
