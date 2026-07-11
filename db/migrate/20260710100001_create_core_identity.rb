class CreateCoreIdentity < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.string  :status, null: false, default: "active"  # active | paused | terminated
      t.string  :timezone, null: false, default: "Asia/Seoul"
      t.string  :country, null: false, default: "KR"
      t.boolean :operator_managed, null: false, default: false
      t.string  :operator_managed_by_email
      t.text    :settings_json, null: false, default: "{}"
      t.timestamps
    end
    add_index :accounts, :slug, unique: true
    add_index :accounts, :status

    create_table :users do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :email_address, null: false
      t.string  :password_digest, null: false
      t.string  :name, null: false, default: ""
      t.string  :role, null: false, default: "owner"  # owner | operator | reviewer
      t.string  :locale, null: false, default: "ko"
      t.datetime :last_login_at
      t.boolean :disabled, null: false, default: false
      t.timestamps
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :ip_address
      t.string  :user_agent
      t.timestamps
    end

    create_table :memberships do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string  :role, null: false, default: "owner"  # owner | admin | reviewer
      t.timestamps
    end

    # 전역 사용자 (계정 무소속 운영자) — 플랫폼 스태프
    create_table :platform_staff do |t|
      t.string  :email_address, null: false
      t.string  :password_digest, null: false
      t.string  :name, null: false, default: ""
      t.string  :role, null: false, default: "staff"  # staff | super_admin
      t.boolean :disabled, null: false, default: false
      t.datetime :last_login_at
      t.timestamps
    end
    add_index :platform_staff, :email_address, unique: true

    create_table :platform_sessions do |t|
      t.references :platform_staff, null: false, foreign_key: { to_table: :platform_staff }
      t.string  :ip_address
      t.string  :user_agent
      t.timestamps
    end
  end
end
