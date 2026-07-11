class CreateApiAndAdmin < ActiveRecord::Migration[8.0]
  def change
    create_table :service_accounts do |t|
      t.references :account, foreign_key: true  # null = 플랫폼 차원
      t.string  :name, null: false
      t.string  :purpose, null: false  # hermes_worker | byreum_test
      t.string  :role, null: false, default: "worker"
      t.boolean :disabled, null: false, default: false
      t.timestamps
    end

    create_table :api_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service_account, foreign_key: true
      t.references :user, foreign_key: true
      t.string  :name, null: false
      t.string  :token_digest, null: false           # SHA256 of raw token
      t.string  :token_prefix, null: false, default: ""
      t.jsonb   :scopes, null: false, default: []
      t.datetime :last_used_at
      t.string  :last_used_ip
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true

    create_table :webhook_endpoints do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :kind, null: false  # discord | instagram | threads
      t.string  :url, null: false
      t.string  :secret_digest, null: false
      t.string  :state, null: false, default: "active"
      t.datetime :last_called_at
      t.string  :last_status
      t.timestamps
    end

    create_table :feature_flags do |t|
      t.string  :key, null: false
      t.references :account, foreign_key: true
      t.boolean :enabled, null: false, default: false
      t.jsonb   :value, null: false, default: {}
      t.timestamps
    end

    create_table :audit_events do |t|
      t.references :account, foreign_key: true
      t.references :actor_user, foreign_key: { to_table: :users }
      t.references :actor_platform_staff, foreign_key: { to_table: :platform_staff }
      t.references :service_account, foreign_key: true
      t.string  :action, null: false
      t.string  :resource_type
      t.bigint :resource_id
      t.jsonb   :metadata, null: false, default: {}
      t.string  :request_id
      t.string  :ip_address
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    create_table :incidents do |t|
      t.references :account, foreign_key: true
      t.string  :severity, null: false, default: "low"  # low | medium | high | critical
      t.string  :title, null: false
      t.text    :description
      t.string  :state, null: false, default: "open"  # open | investigating | resolved | closed
      t.datetime :resolved_at
      t.timestamps
    end

    create_table :notifications do |t|
      t.references :account, foreign_key: true
      t.references :user, foreign_key: true
      t.references :actor_platform_staff, foreign_key: { to_table: :platform_staff }
      t.string  :kind, null: false
      t.string  :title, null: false
      t.text    :body
      t.string  :severity, null: false, default: "info"  # info | warn | error
      t.datetime :read_at
      t.timestamps
    end
  end
end
