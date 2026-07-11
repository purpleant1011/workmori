# Concerns for tenant scoping.  Enables a default scope to the current Account when used.
# MVP uses explicit `where(account_id:)` in controllers; scope below is opt-in via .for_current_account
module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account, optional: false
  end

  class_methods do
    def for_current_account(current_account)
      return none unless current_account
      where(account_id: current_account.id)
    end
  end
end
