class CreateAnnouncements < ActiveRecord::Migration[8.0]
  def change
    create_table :announcements do |t|
      # account_id: NULL 허용 (글로벌 공지 = 모든 사업자에게 보임)
      t.references :account, null: true, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false, default: "info"  # info, warning, critical, promo, internal
      t.string :title, null: false
      t.text :body, null: false
      t.string :audience, null: false, default: "all"  # all, business_owner, platform_staff
      t.string :status, null: false, default: "draft"  # draft, published, archived
      t.datetime :published_at
      t.references :created_by_platform_staff, null: true, foreign_key: { to_table: :platform_staff, on_delete: :nullify }
      t.integer :priority, null: false, default: 0

      t.timestamps
    end

    add_index :announcements, [:status, :audience, :published_at]
    add_index :announcements, [:account_id, :status]
  end
end