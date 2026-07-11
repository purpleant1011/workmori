class AutoReport
  # 일간 리포트: 결과 metrics + 사장 추천 개선 메시지
  # target_date는 '어제(또는 지정일)' — 매일 아침 7시 직전 실행 가정
  def self.daily(account:, target_date:)
    return nil if account.nil?
    target_date = target_date.to_date
    today_start = target_date.beginning_of_day
    today_end   = target_date.end_of_day

    content_scope = ContentItem.where(account_id: account.id).where(created_at: today_start..today_end)
    content_created  = content_scope.count
    content_approved = content_scope.where(state: %w[approved scheduled published]).count
    content_published = content_scope.where(state: "published").count
    content_failed   = content_scope.where(state: %w[failed rejected]).count

    # Inquiry는 글로벌 풀 (현재 모델에 account_id 없음). 가까운 통계를 위해 Handoff/Message 사용
    inquiry_count = Inquiry.where(created_at: today_start..today_end).count rescue 0
    handoff_count = Handoff.where(account_id: account.id).where(created_at: today_start..today_end).count
    safety_logs   = SafetyLog.where(account_id: account.id).where(created_at: today_start..today_end)
    blocked       = safety_logs.where(verdict: %w[blocked needs_review]).count

    usage         = UsageRecord.where(account_id: account.id).where(occurred_at: today_start..today_end)
    ai_tokens     = usage.sum("input_tokens + output_tokens")
    ai_cost_krw   = usage.sum(:cost_krw).to_i

    improvements = []
    improvements << "오늘은 안전 정책에 의해 #{blocked}건이 차단되었습니다. 지식 베이스를 보강하면 자동 응답률이 올라갑니다." if blocked.positive?
    improvements << "발행까지 걸린 평균 시간이 길어 보입니다. 자동 스케줄 시간을 단축하거나 채널을 추가하세요." if content_created.positive? && content_published.zero?
    improvements << "사람 인계가 #{handoff_count}건 있습니다. 인계 사유를 지식 베이스에 추가하면 자동화가 가능합니다." if handoff_count >= 3
    improvements << "AI 비용이 #{ai_cost_krw}원 발생했습니다. 비용 한도를 점검해 주세요." if ai_cost_krw > 10_000

    {
      account_id: account.id,
      target_date: target_date,
      content_created_count: content_created,
      content_approved_count: content_approved,
      content_published_count: content_published,
      content_failed_count: content_failed,
      inquiry_count: inquiry_count,
      handoff_count: handoff_count,
      blocked_count: blocked,
      ai_token_used: ai_tokens.to_i,
      ai_cost_krw: ai_cost_krw,
      improvement_suggestions: improvements,
      summary: "[일간] 생성 #{content_created} / 발행 #{content_published} / 인계 #{handoff_count} / 안전차단 #{blocked}",
    }
  end

  # 주간 리포트: WeeklyReport row를 만들어 영속화 — reporting view에서 조회
  def self.weekly(account:, week_start:, week_end:)
    return nil if account.nil?
    week_start = week_start.to_date
    week_end   = week_end.to_date
    start_at = week_start.beginning_of_day
    end_at   = week_end.end_of_day

    content_scope = ContentItem.where(account_id: account.id).where(created_at: start_at..end_at)
    usage_scope   = UsageRecord.where(account_id: account.id).where(occurred_at: start_at..end_at)

    improvements = weekly_improvements_for(account, content_scope, usage_scope)

    WeeklyReport.create!(
      account: account,
      week_start_on: week_start,
      week_end_on: week_end,
      content_created_count: content_scope.count,
      content_approved_count: content_scope.where(state: %w[approved scheduled published]).count,
      content_published_count: content_scope.where(state: "published").count,
      content_failed_count: content_scope.where(state: %w[failed rejected]).count,
      inquiry_count: (Inquiry.where(created_at: start_at..end_at).count rescue 0),
      handoff_count: Handoff.where(account_id: account.id).where(created_at: start_at..end_at).count,
      ai_token_used: (usage_scope.sum("input_tokens + output_tokens").to_i rescue 0),
      ai_cost_krw: usage_scope.sum(:cost_krw).to_i,
      summary: "[주간] 생성 #{content_scope.count} / 발행 #{content_scope.where(state: 'published').count} / 인계 #{Handoff.where(account_id: account.id).where(created_at: start_at..end_at).count}",
      improvement_suggestions: improvements,
      state: "generated",
    )
  end

  def self.weekly_improvements_for(account, content_scope, usage_scope)
    improvements = []
    failures = content_scope.where(state: %w[failed rejected]).count
    improvements << "이번 주 실패/반려 콘텐츠가 #{failures}건. 작성 가이드라인을 보강하세요." if failures.positive?
    total_cost = usage_scope.sum(:cost_krw).to_i
    improvements << "주간 AI 비용 #{total_cost}원. 비용 한도 재설정을 검토하세요." if total_cost > 50_000
    knowledge_docs = KnowledgeDocument.where(account_id: account.id).count
    improvements << "지식 베이스 문서 #{knowledge_docs}건. 자주 묻는 질문 답변을 추가하면 자동 응답률이 올라갑니다." if knowledge_docs < 5
    improvements
  end
end
