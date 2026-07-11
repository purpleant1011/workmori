class AddTokenExpiryColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :platform_sessions, :expires_at, :datetime
    add_column :sessions, :expires_at, :datetime
  end
end
