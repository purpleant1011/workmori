class AddSessionTokenColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :revoked_at, :datetime
    add_column :sessions, :token_hash, :string
    add_index  :sessions, :token_hash
    add_column :sessions, :last_seen_at, :datetime
  end
end
