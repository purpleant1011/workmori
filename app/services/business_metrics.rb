# BusinessMetrics — 사업자 대시보드용 KPI 계산
# 범위: 최근 N일 (since)
class BusinessMetrics
  Result = Struct.new(
    :content_total, :content_published, :content_pending, :content_scheduled,
    :publish_attempts, :publish_succeeded, :publish_success_rate,
    :active_channels, :channels_by_kind,
    :conversations_total, :conversations_responded, :response_rate,
    :handoffs_open, :handoffs_total,
    :automations_run, :automations_succeeded, :automation_success_rate,
    :inquiries_total,
    :revenue_paid_krw, :revenue_outstanding_krw, :invoice_count_paid, :invoice_count_open,
    :csat_score, :csat_responses,
    keyword_init: true
  )

  def self.call(account:, since: 7.days.ago.beginning_of_day)
    new(account: account, since: since).call
  end

  def initialize(account:, since:)
    @account = account
    @since = since
  end

  def call
    # 콘텐츠
    contents = @account.content_items.where("created_at >= ?", @since)
    content_total      = contents.count
    content_published  = contents.where(state: "published").count
    content_pending    = @account.content_items.where(state: "pending_review").count
    content_scheduled  = @account.content_items.where(state: "scheduled").count

    # 발행
    attempts = @account.publication_attempts.where("created_at >= ?", @since)
    publish_attempts    = attempts.count
    publish_succeeded   = attempts.where(state: "succeeded").count
    publish_success_rate = publish_attempts.zero? ? 0.0 : (publish_succeeded.to_f / publish_attempts * 100).round(1)

    # 채널
    active_channels = @account.channel_connections.where(status: "active").count
    channels_by_kind = @account.channel_connections.where(status: "active").group(:kind).count

    # 대화/응답
    convs = @account.conversations.where("created_at >= ?", @since)
    conversations_total    = convs.count
    conversations_responded = convs.where.not(state: "open").count
    response_rate = conversations_total.zero? ? 0.0 : (conversations_responded.to_f / conversations_total * 100).round(1)

    # 인계
    handoffs_total = @account.handoffs.where("created_at >= ?", @since).count
    handoffs_open  = @account.handoffs.where(state: "pending").count

    # 자동화
    autos = @account.automation_executions.where("created_at >= ?", @since)
    automations_run       = autos.count
    automations_succeeded = autos.where(state: "succeeded").count
    automation_success_rate = automations_run.zero? ? 0.0 : (automations_succeeded.to_f / automations_run * 100).round(1)

    # 문의 (글로벌 Inquiry 풀 — account_id 필터 가능 시 적용)
    inquiries_total = Inquiry.where("created_at >= ?", @since).count

    # 매출
    paid_invs = @account.invoices.where(state: "paid", paid_on: @since.to_date..Date.current)
    open_invs = @account.invoices.where(state: "issued")
    revenue_paid_krw       = paid_invs.sum(:final_amount_krw)
    revenue_outstanding_krw = open_invs.sum(:final_amount_krw)
    invoice_count_paid = paid_invs.count
    invoice_count_open = open_invs.count

    # CSAT
    csat_responses = @account.csat_responses.where("created_at >= ?", @since)
    csat_score = csat_responses.count.zero? ? nil : (csat_responses.average(:score)&.to_f&.round(2))

    Result.new(
      content_total: content_total, content_published: content_published,
      content_pending: content_pending, content_scheduled: content_scheduled,
      publish_attempts: publish_attempts, publish_succeeded: publish_succeeded,
      publish_success_rate: publish_success_rate,
      active_channels: active_channels, channels_by_kind: channels_by_kind,
      conversations_total: conversations_total, conversations_responded: conversations_responded,
      response_rate: response_rate,
      handoffs_open: handoffs_open, handoffs_total: handoffs_total,
      automations_run: automations_run, automations_succeeded: automations_succeeded,
      automation_success_rate: automation_success_rate,
      inquiries_total: inquiries_total,
      revenue_paid_krw: revenue_paid_krw.to_i, revenue_outstanding_krw: revenue_outstanding_krw.to_i,
      invoice_count_paid: invoice_count_paid, invoice_count_open: invoice_count_open,
      csat_score: csat_score, csat_responses: csat_responses.count
    )
  end
end