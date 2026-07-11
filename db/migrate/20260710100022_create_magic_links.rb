class CreateMagicLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :magic_links do |t|
      t.string  :email, null: false
      t.string  :token_hash, null: false
      t.string  :purpose, null: false, default: "user_login"
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.string  :ip_address
      t.timestamps
    end
    add_index :magic_links, :token_hash, unique: true
    add_index :magic_links, [:email, :purpose]
    add_index :magic_links, :expires_at
  end
end
