class AutomationSchedule < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :automation_rule

  CADENCE_LABELS = {
    "hourly"  => "매시",
    "daily"   => "매일",
    "weekly"  => "매주",
    "monthly" => "매월",
    "cron"    => "cron",
    "one_off" => "일회성"
  }.freeze

  def compute_next_run_from(now = Time.current)
    case cadence
    when "hourly"
      now.beginning_of_hour + 1.hour
    when "daily"
      base = now.beginning_of_day + (read_attribute(:hour) || 9).hours
      base <= now ? base + 1.day : base
    when "weekly"
      base = now.beginning_of_day + (read_attribute(:hour) || 9).hours
      base <= now ? base + 1.week : base
    when "monthly"
      base = now.beginning_of_month + (read_attribute(:hour) || 9).hours
      base <= now ? base + 1.month : base
    when "cron"
      now + 1.day
    when "one_off"
      read_attribute(:next_run_at) || now
    else
      now + 1.day
    end
  end

  def summary
    label = CADENCE_LABELS[cadence] || cadence.to_s
    base = case cadence
    when "hourly"
      "#{label} (매 정각)"
    when "daily", "weekly", "monthly"
      h = read_attribute(:hour)
      "#{label} #{h.present? ? "#{h}시" : '09시'}"
    when "cron"
      "#{label}: #{cron_expression.presence || '(미설정)'}"
    when "one_off"
      t = read_attribute(:next_run_at)
      "#{label} (#{t&.strftime('%Y-%m-%d %H:%M') || '미설정'})"
    else
      label
    end
    if last_run_at
      "#{base} · 마지막 실행 #{last_run_at.strftime('%m-%d %H:%M')}"
    else
      "#{base} · 아직 실행 기록 없음"
    end
  end
end
