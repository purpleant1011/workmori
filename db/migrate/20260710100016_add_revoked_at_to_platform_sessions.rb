class AddRevokedAtToPlatformSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :platform_sessions, :revoked_at, :datetime
    add_column :platform_sessions, :token_hash, :string
    add_index  :platform_sessions, :token_hash
  end
end
