# frozen_string_literal: true

# 매일 정해진 시각에 Instagram/Threads 자동 응대 + 인사이트 수집
class EngagementTickJob < ApplicationJob
  queue_as :default

  def perform
    ChannelConnection.where(kind: %w[instagram threads], status: "active").find_each do |channel|
      ai_employee = channel.ai_employee || channel.account.ai_employees.first

      if channel.kind == "instagram"
        Engagement::Automator.auto_reply_instagram_comments(channel, ai_employee: ai_employee)
        Engagement::Automator.collect_instagram_insights(channel)
      elsif channel.kind == "threads"
        Engagement::Automator.auto_reply_threads_comments(channel, ai_employee: ai_employee)
      end
    end
  rescue => e
    Rails.logger.warn("[EngagementTickJob] failed: #{e.class}: #{e.message[0,200]}")
  end
end