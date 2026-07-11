class Budget < ApplicationRecord
  include AccountScoped
  belongs_to :account

  def percent_used
    return 0 if limit_value.to_i.zero?
    ((current_value.to_f / limit_value) * 100).round
  end

  def threshold_crossed?(level)
    percent_used >= level
  end
end
