class Automation::RunJob < ApplicationJob
  queue_as :default

  def perform(automation_rule_id:, account_id: nil, execution_id: nil)
    rule = AutomationRule.find_by(id: automation_rule_id)
    return { skipped: "rule not found" } unless rule
    account = Account.find_by(id: account_id || rule.account_id)
    return { skipped: "account not found" } unless account

    execution = nil
    if execution_id
      execution = AutomationExecution.find_by(id: execution_id)
    end
    unless execution
      execution = AutomationExecution.create!(
        account: account,
        automation_rule: rule,
        ai_employee_id: rule.ai_employee_id,
        schedule_kind: "manual",
        trigger_kind: "manual",
        state: "starting",
        attempts: 1,
        scheduled_at: Time.current,
        started_at: Time.current,
        idempotency_key: "manual-#{rule.id}-#{Time.current.to_i}-#{SecureRandom.hex(4)}"
      )
    end

    ActiveRecord::Base.transaction do
      execution.update!(state: "running")
      payload = {
        rule_id: rule.id,
        account_id: account.id,
        intent_kind: rule.intent_kind,
        natural_language: rule.natural_language,
        run_at: Time.current.iso8601
      }
      result = Automation::Provider.active.execute(rule: rule, payload: payload)

      pipeline_result = Content::Pipeline.run(
        account: account,
        ai_employee: rule.ai_employee,
        automation_rule: rule,
        intent: rule.intent_kind,
        schedule_kind: "manual"
      )
      content = pipeline_result.content_item
      output = result.dig(:output) || {}
      if output[:title].present? || output[:body].present?
        content.update!(title: output[:title].presence || content.title, body: output[:body].presence || content.body)
        ContentVersion.create!(
          account: content.account,
          content_item: content,
          version_number: (content.content_versions.maximum(:version_number) || 0) + 1,
          body: content.body,
          caption: content.caption,
          hashtags_json: content.hashtags_json,
          changed_by_user: nil
        )
      end

      execution.update!(state: "succeeded", finished_at: Time.current, content_item_id: content.id, result_payload_json: result.to_json)
      execution
    end
  rescue StandardError => e
    Rails.logger.error("[Automation::RunJob] #{e.class}: #{e.message}")
    if execution
      execution.update(state: "failed", finished_at: Time.current, error_message: e.message)
    end
    raise
  end
end
