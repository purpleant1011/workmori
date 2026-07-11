# frozen_string_literal: true

class App::EngagementsController < App::BaseController
  # Instagram/Threads 자동 응대 수동 트리거
  def create
    @channel = @current_account.channel_connections.find(params[:channel_id])
    @ai_employee = @channel.ai_employee || @current_account.ai_employees.first

    result = case @channel.kind
    when "instagram"
      {
        auto_reply: Engagement::Automator.auto_reply_instagram_comments(@channel, ai_employee: @ai_employee),
        insights:   Engagement::Automator.collect_instagram_insights(@channel)
      }
    when "threads"
      { auto_reply: Engagement::Automator.auto_reply_threads_comments(@channel, ai_employee: @ai_employee) }
    else
      { skipped: "지원하지 않는 채널: #{@channel.kind}" }
    end

    @result = result
    AuditEvent.create!(
      account: @current_account,
      action: "engagement.manual_run",
      resource_type: "ChannelConnection",
      resource_id: @channel.id,
      metadata: { kind: @channel.kind, result: result.to_h },
      occurred_at: Time.current
    )
    render :show
  rescue => e
    flash[:alert] = "Engagement 실행 실패: #{e.class}: #{e.message[0,200]}"
    redirect_to app_channels_path
  end

  def show
    @channel = @current_account.channel_connections.find(params[:id])
    @recent_events = AuditEvent.where(action: "engagement.auto_reply", resource_id: @channel.id)
                               .order(created_at: :desc).limit(20)
  end
end