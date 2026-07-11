class AddTrialEndsAtToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :trial_ends_at, :datetime
    add_index :accounts, :trial_ends_at
  end
end