# frozen_string_literal: true

# P2-3 검증: ChangeProposal 워크플로우 (승인/거절/24시간 자동 만료)
account = Account.first
business = BusinessProfile.find_or_create_by!(account_id: account.id) do |bp|
  bp.trade_name = "P2-제안테스트"
  bp.legal_name = "P2제안 주식회사"
  bp.owner_name = "P2 제안"
  bp.industry_code = "restaurant"
  bp.region_label = "서울"
end
ai = business.account.ai_employees.first || AiEmployee.create!(account_id: account.id, name: "P2 제안 AI", role_label: "응대 직원", persona_preset: "warm_local", status: "active")
user = User.first

# 이전 테스트 제안 정리
ChangeProposal.where(business_profile_id: business.id).destroy_all

# 1. 승인 흐름
p_approve = ChangeProposal.create!(
  business_profile_id: business.id, ai_employee_id: ai.id,
  target_kind: "runtime_config", target_field: "tone_warm",
  proposed_payload: { tone: "warm", examples: %w[안녕하세요 감사합니다] },
  previous_payload: {}, reason: "고객이 따뜻한 톤 요청", user_quote: "좀 더 따뜻하게 말해줘",
  status: "pending"
)
puts "[P2-3] created proposal ##{p_approve.id} status=pending expires_at=#{p_approve.expires_at}"

# 즉시 승인
p_approve.approve!(actor: user, discord_id: "111")
puts "[P2-3] approve! => status=#{p_approve.reload.status} decided_by_discord_id=#{p_approve.decided_by_discord_id}"
puts "[P2-3] approvals: #{p_approve.change_approvals.count}, action=#{p_approve.change_approvals.first.action}"

# 2. 거절 흐름
p_reject = ChangeProposal.create!(
  business_profile_id: business.id, ai_employee_id: ai.id,
  target_kind: "business_profile", target_field: "phone_number",
  proposed_payload: { phone: "010-9999-9999" },
  previous_payload: {}, reason: "전화번호 공개 변경 시도 (부적절)", user_quote: "전화번호 바꿔",
  status: "pending"
)
p_reject.reject!(actor: user, discord_id: "222", comment: "개인정보 변경은 직접 사업장 편집에서")
puts "[P2-3] reject! => status=#{p_reject.reload.status} comment=#{p_reject.change_approvals.find_by(action: 'reject')&.comment}"

# 3. 24시간 만료 흐름 — 과거 expires_at으로 제안 1건 생성
p_expire = ChangeProposal.create!(
  business_profile_id: business.id, ai_employee_id: ai.id,
  target_kind: "runtime_config", target_field: "promo_message",
  proposed_payload: { promo: "오늘만 50% 할인" },
  previous_payload: {}, reason: "프로모션 문구", user_quote: "프로모션 등록",
  status: "pending"
)
p_expire.update_column(:expires_at, 1.hour.ago)
puts "[P2-3] created proposal ##{p_expire.id} status=pending expires_at=#{p_expire.expires_at} (1시간 전)"

# 게이트 ON
flag = FeatureFlag.find_by!(key: "discord_native_enabled", account_id: nil)
flag.update!(enabled: true)
FeatureFlags.flush_cache!

# 만료 Job 실행
expired = ExpireChangeProposalsJob.new.perform
puts "[P2-3] ExpireChangeProposalsJob => expired_count=#{expired}"
puts "[P2-3] p_expire.status=#{p_expire.reload.status} approvals_count=#{p_expire.change_approvals.count}"

# 다른 pending 제안이 만료 대상이 아닌지 검증
non_expired = ChangeProposal.where(business_profile_id: business.id, status: "pending").where("expires_at > ?", Time.current).count
puts "[P2-3] non-expired pending count=#{non_expired} (만료 안 된 것만)"

# 4. 보류 + 만료 + 승인 후 재시도 검증
p_double = ChangeProposal.create!(
  business_profile_id: business.id, ai_employee_id: ai.id,
  target_kind: "faq", target_field: "answer_policy",
  proposed_payload: { policy: "신규" },
  previous_payload: {}, reason: "중복 시도", user_quote: "정책 변경",
  status: "pending"
)
p_double.update_column(:expires_at, 1.minute.ago)
result1 = ExpireChangeProposalsJob.new.perform
result2 = ExpireChangeProposalsJob.new.perform
puts "[P2-3] double expire: run1=#{result1} run2=#{result2} (멱등하게 0 또는 같은 수)"
puts "[P2-3] p_double.status=#{p_double.reload.status} approvals=#{p_double.change_approvals.where(action: 'expire').count}"

# 5. AuditEvent 검증
audit = AuditEvent.where(resource_type: "ChangeProposal", action: "change_proposal.expired").order(occurred_at: :desc).limit(2)
puts "[P2-3] AuditEvent(expired): count=#{audit.count}"
audit.each { |a| puts "[P2-3]   - id=#{a.id} resource_id=#{a.resource_id} metadata=#{a.metadata}" }

# 게이트 복구
flag.update!(enabled: false)
FeatureFlags.flush_cache!
puts "[P2-3] gate restored enabled=#{flag.reload.enabled}"
puts "[P2-3] DONE"