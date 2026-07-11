class App::ContentItemsController < App::BaseController
  def index
    @contents = @current_account.content_items.order(created_at: :desc).limit(100)
  end

  def pending_for_review
    @pending = @current_account.content_items.where(state: %w[needs_review generated]).order(created_at: :desc)
    @contents = @pending
    render :index
  end

  def show
    @content = @current_account.content_items.find(params[:id])
    @approval = @content.approval_request
    @versions = @content.content_versions.order(version_number: :asc)
    @attempts = @content.publication_attempts.order(created_at: :desc).limit(20)
  end

  # generate: 사업자가 직접 새 콘텐츠 생성 트리거
  def generate
    ai_employee = @current_account.ai_employees.find_by(id: params[:ai_employee_id]) || @current_account.ai_employees.first
    intent = params[:intent].presence || "feed"
    schedule_kind = params[:schedule_kind].presence || "manual"

    result = Content::Pipeline.run(
      account: @current_account,
      ai_employee: ai_employee,
      intent: intent,
      schedule_kind: schedule_kind,
    )

    AuditEvent.create!(
      account: @current_account,
      action: "content.generated",
      resource_type: "ContentItem",
      resource_id: result.content_item.id,
      metadata: { verdict: result.safety_result[:verdict], intent: intent, schedule_kind: schedule_kind },
      occurred_at: Time.current,
    )

    flash[:notice] = "콘텐츠 생성 완료 (#{result.safety_result[:verdict]}): #{result.content_item.title}"
    redirect_to app_content_item_path(result.content_item)
  end

  def approve
    @content = @current_account.content_items.find(params[:id])
    decision_notes = params[:notes].presence
    ar = @content.approval_request

    if ar&.pending?
      ar.decide!(decision: "approved", user: current_user, notes: decision_notes)
    end
    scheduled_at = params[:scheduled_at].presence
    @content.update!(
      state: "approved",
      safety_notes: (@content.safety_notes || {}).merge("approved_by_user_id" => current_user.id),
    )
    if scheduled_at
      @content.update!(scheduled_at: scheduled_at, state: "scheduled")
    else
      ContentScheduler.enqueue_publisher(@content)
    end
    redirect_to app_content_item_path(@content), notice: scheduled_at ? "예약되었습니다." : "승인 후 발행 큐에 등록되었습니다."
  end

  def reject
    @content = @current_account.content_items.find(params[:id])
    decision_notes = params[:notes].presence
    ar = @content.approval_request
    if ar&.pending?
      ar.decide!(decision: "rejected", user: current_user, notes: decision_notes)
    end
    @content.update!(state: "failed")
    redirect_to app_content_item_path(@content), notice: "반려되었습니다."
  end

  # 사업자가 콘텐츠 직접 수정 (저장 시 새 버전 기록)
  def update
    @content = @current_account.content_items.find(params[:id])
    previous_body = @content.body
    title = params[:content_item][:title].presence || @content.title
    body = params[:content_item][:body].presence || @content.body
    caption = params[:content_item][:caption].presence || @content.caption
    @content.update!(title: title, body: body, caption: caption)

    last_version = @content.content_versions.order(version_number: :desc).first
    ContentVersion.create!(
      account: @current_account,
      content_item: @content,
      version_number: (last_version&.version_number || 0) + 1,
      body: body,
      caption: caption,
      hashtags_json: @content.hashtags_json,
      changed_by_user: current_user,
      diff_from_previous: { delta_chars: (body.to_s.length - previous_body.to_s.length) },
    )

    # 수정 후 다시 안전 검증 — needs_review/blocked면 state도 이동
    new_safety = Safety::Policy.check!(
      content: "#{body}\n#{caption}",
      account: @current_account,
      stage: "pre_publish",
      persist: true,
    )
    @content.update!(
      safety_state: new_safety.verdict == "blocked" ? "blocked" : (new_safety.verdict == "needs_review" ? "needs_review" : "passed"),
      safety_notes: { verdict: new_safety.verdict, hits: new_safety.hits, rules: new_safety.rules, edited_at: Time.current },
    )
    if @content.state == "needs_review" || (@content.safety_state == "blocked")
      # blocked면 manual review 큐에 들어가야 함
      ApprovalRequest.find_or_create_by!(content_item: @content, state: "pending") do |r|
        r.account = @current_account
        r.expires_at = Time.current + 24.hours
      end
    end

    redirect_to app_content_item_path(@content), notice: "수정 사항이 저장되고 새 버전이 기록되었습니다."
  end

  # 즉시 게시 — ready_for_publish 채널 필요 (없으면 mock fallback)
  def publish_now
    @content = @current_account.content_items.find(params[:id])
    if @content.state == "needs_review" || @content.safety_state == "blocked"
      flash[:alert] = "검수 대기 또는 차단된 콘텐츠는 바로 게시할 수 없습니다."
      return redirect_to(app_content_item_path(@content))
    end
    ContentScheduler.enqueue_publisher(@content)
    redirect_to app_content_item_path(@content), notice: "발행 큐에 등록되었습니다."
  end

  def schedule
    @content = @current_account.content_items.find(params[:id])
    scheduled_at = params[:scheduled_at].presence
    if scheduled_at.blank?
      flash[:alert] = "예약 시간이 필요합니다."
      return redirect_to(app_content_item_path(@content))
    end
    @content.update!(scheduled_at: scheduled_at, state: "scheduled")
    ContentScheduler.enqueue_publisher(@content)
    redirect_to app_content_item_path(@content), notice: "예약 게시 큐에 등록되었습니다."
  end

  def archive
    @content = @current_account.content_items.find(params[:id])
    @content.update!(state: "archived")
    redirect_to app_content_items_path, notice: "보관되었습니다."
  end

  def publish_to_channel
    @content = @current_account.content_items.find(params[:id])
    channel = @current_account.channel_connections.find(params[:channel_id])
    res = Channels::Publisher.call(channel: channel, content_item: @content)
    if res.ok
      redirect_to app_content_item_path(@content), notice: "#{channel.kind}에 게시 완료"
    else
      redirect_to app_content_item_path(@content), alert: "게시 실패: #{res.error}"
    end
  end

  def edit
    @content = @current_account.content_items.find(params[:id])
  end

  def new
    @ai_employees = @current_account.ai_employees.order(:name)
    @intents = ContentItem::KINDS
  end
end
