#!/usr/bin/env ruby
# frozen_string_literal: true
# todo #6 시드 — 자동화 규칙 + 일정 + 실행 이력 5종
# 사용법: bin/rails runner script/seed_rule6.rb

require "active_record/base"

account = Account.first
if account.nil?
  puts "❌ Account.first 가 없습니다 — bin/rails db:seed 먼저 실행해주세요"
  exit 1
end

employee = account.ai_employees.first
if employee.nil?
  puts "❌ AIEmployee이 없습니다 — db:seed에 AI 직원 생성을 추가해주세요"
  exit 1
end

ActiveRecord::Base.transaction do
  # 기존 자동화 규칙 정리 (idempotent)
  account.automation_rules.destroy_all


  rules = [
    {
      name: "신메뉴 안내",
      natural_language: "매일 오후 9시에 신메뉴를 홍보 채널에 자동 게시",
      intent_kind: "post",
      structured_plan: { "trigger" => "schedule", "action" => "post_feed", "tone" => "bright_active" },
      constraints: { "quiet_hours" => ["22:00-09:00"], "no_emoji" => false },
      cadence: "daily",
      hour: 21
    },
    {
      name: "주간 매출 리포트",
      natural_language: "매주 월요일 오전 9시에 지난 주 매출 리포트를 사장님께 이메일 + 사업자 대시보드 알림으로 발송",
      intent_kind: "report",
      structured_plan: { "trigger" => "weekly", "report_kind" => "sales_weekly", "channels" => ["email", "in_app"] },
      constraints: { "weekday" => "monday" },
      cadence: "weekly",
      hour: 9
    },
    {
      name: "FAQ 자동 응답",
      natural_language: "신규 문의 중 자주 묻는 질문은 즉시 AI가 응답 처리 (단, 민감 문의는 사람에게 인계)",
      intent_kind: "reply",
      structured_plan: { "trigger" => "new_inquiry", "action" => "auto_reply", "max_tokens" => 200, "escalate_keywords" => ["환불", "불만", "민원"] },
      constraints: { "approval_required" => false, "require_keywords" => [] },
      cadence: "cron",
      cron_expression: "*/15 * * * *"
    },
    {
      name: "FAQ 데이터 자동 업데이트",
      natural_language: "매주 일요일 자정에 운영자가 승인한 Q&A를 AI 직원 지식 베이스에 자동 병합",
      intent_kind: "faq_update",
      structured_plan: { "trigger" => "weekly", "source" => "approved_qa_thread", "action" => "merge_to_rag" },
      constraints: { "require_approval" => true },
      cadence: "weekly",
      hour: 0
    },
    {
      name: "메뉴판 이미지 자동 백업",
      natural_language: "매월 1일 새벽 3시에 최신 메뉴판 이미지와 매출 CSV를 압축하여 사업주 관리자에게 전송",
      intent_kind: "data_export",
      structured_plan: { "trigger" => "monthly", "format" => "zip", "targets" => ["menu_images", "sales_csv"] },
      constraints: { "compression" => "gzip" },
      cadence: "monthly",
      hour: 3
    }
  ]

  rules.each do |attrs|
    cadence = attrs.delete(:cadence)
    hour = attrs.delete(:hour)
    cron_expression = attrs.delete(:cron_expression)

    rule = account.automation_rules.create!(
      ai_employee: employee,
      name: attrs[:name],
      natural_language: attrs[:natural_language],
      intent_kind: attrs[:intent_kind],
      structured_plan: attrs[:structured_plan],
      constraints: attrs[:constraints],
      status: "active",
      approved_by_user_id: account.users.first&.id,
      approved_at: Time.current,
      approval_notes: "초기 자동 승인 (시스템 시드)"
    )

    schedule = rule.automation_schedules.build(
      account: account,
      cadence: cadence,
      cron_expression: cron_expression,
      quiet_hours: { "start" => "22:00", "end" => "09:00" },
      next_run_at: case cadence
                   when "daily" then Time.current.tomorrow.change(hour: hour || 9).beginning_of_hour
                   when "weekly" then 1.week.from_now.change(hour: hour || 9).beginning_of_hour
                   when "monthly" then 1.month.from_now.change(hour: hour || 9).beginning_of_hour
                   when "cron" then 15.minutes.from_now
                   when "hourly" then 1.hour.from_now
                   else 1.day.from_now
                   end,
      last_run_at: nil
    )
    schedule.save!

    # 시뮬레이션: 1건은 이미 1회 실행 완료 상태로
    if rule.name == "신메뉴 안내"
      execution = rule.automation_executions.create!(
        account: account,
        ai_employee: employee,
        state: "succeeded",
        started_at: 1.day.ago,
        finished_at: 1.day.ago + 30.seconds,
        schedule_kind: "scheduled",
        trigger_kind: "schedule",
        idempotency_key: "seed_rule6_#{rule.id}_day1",
        input_json: { "schedule_id" => schedule.id },
        output_json: { "post_id" => "mock_#{SecureRandom.hex(4)}", "tone" => "bright_active" },
        result_payload_json: { "channel" => "instagram", "preview" => "신메뉴 1건 자동 게시 완료" }
      )
      DeliveryLog.create!(
        account: account,
        kind: "automation_summary",
        subject: "[자동] #{rule.name}",
        body_excerpt: execution.output_json["preview"],
        recipient_count: 1,
        delivered_at: execution.finished_at,
        external_provider: "instagram",
        result_payload: { "automation_rule_id" => rule.id, "execution_id" => execution.id, "channel" => "instagram" }
      )
    end

    puts "✅ 자동화 규칙 생성: #{rule.name} (intent_kind=#{rule.intent_kind}, cadence=#{cadence})"
  end

  # 자동화 규칙 실행 이력 추가 (대시보드용)
  if rules.length > 1
    target = account.automation_rules.second
    5.times do |i|
      target.automation_executions.create!(
        account: account,
        ai_employee: employee,
        state: "succeeded",
        started_at: (i + 1).days.ago,
        finished_at: (i + 1).days.ago + 8.seconds,
        schedule_kind: "scheduled",
        trigger_kind: "schedule",
        idempotency_key: "seed_rule6_#{target.id}_week_#{i}",
        input_json: { "period" => "weekly" },
        output_json: { "report_id" => i + 1, "summary" => "주간 매출 리포트 #{i + 1}회차" }
      )
    end
    puts "✅ 자동화 실행 이력 +5 추가"
  end
end

puts ""
puts "=== todo #6 시드 완료 ==="
puts "Account: #{account.name} (#{account.id})"
puts "AI Employee: #{employee.name} (#{employee.id})"
puts "자동화 규칙 수: #{account.automation_rules.count}개"
puts "자동화 일정 수: #{account.automation_schedules.count}개"
puts "자동화 실행 이력: #{account.automation_executions.count}건"
puts "배달 이력: #{account.delivery_logs.where(kind: 'automation_summary').count}건"
