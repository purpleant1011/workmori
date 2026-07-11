class AutomationTickJob < ApplicationJob
  queue_as :default

  # 매 시간 정각 자동 트리거 (scheduler에서 호출)
  # 수동 호출도 가능: AutomationTickJob.perform_now
  def perform(hour: Time.current.hour)
    now = Time.current

    # 1) 일정 시각이 도래한 자동화 일정 매칭 (next_run_at <= now)
    AutomationSchedule
      .where("next_run_at IS NULL OR next_run_at <= ?", now)
      .where(cadence: %w[daily weekly monthly hourly cron one_off])
      .find_each do |schedule|
      Rails.logger.info "[AutomationTickJob] 매칭 schedule=#{schedule.id} rule=#{schedule.automation_rule_id} cadence=#{schedule.cadence}"

      rule = schedule.automation_rule
      next if rule.nil? || !rule.status.to_s.in?(%w[active])

      execution = AutomationExecution.create!(
        account_id: schedule.account_id,
        ai_employee_id: rule.ai_employee_id,
        automation_rule_id: rule.id,
        state: "queued",
        schedule_kind: schedule.cadence,
        trigger_kind: "tick",
        idempotency_key: "tick_#{schedule.id}_#{now.to_i}",
        input_json: { "schedule_id" => schedule.id, "cadence" => schedule.cadence, "hour" => hour },
        scheduled_at: now
      )

      Automation::RunJob.perform_later(automation_rule_id: rule.id, account_id: schedule.account_id, execution_id: execution.id)
      schedule.update_columns(last_run_at: now, next_run_at: schedule.compute_next_run_from(now))
    end
  end
end
