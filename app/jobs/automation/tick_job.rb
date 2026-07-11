class Automation::TickJob < ApplicationJob
  queue_as :default

  def perform
    AutomationSchedule.where(enabled: true).or(AutomationSchedule.where(enabled: nil)).find_each do |sched|
      next unless sched.next_run_at && sched.next_run_at <= Time.current
      rule = sched.automation_rule
      next unless rule && rule.status == "active"
      AutomationExecution.create!(account: rule.account, automation_rule: rule, ai_employee_id: rule.ai_employee_id, schedule_kind: sched.cadence, state: "queued", attempts: 1, scheduled_at: Time.current, idempotency_key: "tick-#{rule.id}-#{Time.current.to_i}-#{SecureRandom.hex(4)}")
      Automation::RunJob.perform_later(AutomationExecution.where(automation_rule: rule).last.id)
      sched.update!(next_run_at: sched.next_run_at + 1.week)
    end
  end
end
