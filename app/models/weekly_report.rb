class WeeklyReport < ApplicationRecord
  include AccountScoped
  belongs_to :account
end
