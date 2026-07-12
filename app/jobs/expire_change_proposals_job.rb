# frozen_string_literal: true

# ExpireChangeProposalsJob — 24시간 지난 pending 제안을 expired로 전환
# 원칙 9: 영구 변경 = 제안 → 확인 → 적용. 확인 안 된 제안은 자동 만료.
# 원칙: customer-facing 안전한 작업 (status 변경 + 감사 로그만)
class ExpireChangeProposalsJob < DiscordNativeJob
  queue_as :default

  def perform
    return unless FeatureFlags.enabled?(:discord_native_enabled)

    expired_count = 0
    ChangeProposal.where(status: "pending")
                  .where("expires_at <= ?", Time.current)
                  .find_each(batch_size: 50) do |proposal|
      ChangeProposal.transaction do
        proposal.change_approvals.create!(
          discriminator_discord_id: "system",
          action: "expire",
          comment: "24시간 내 결정 없음 — 자동 만료"
        )
        proposal.update!(status: "expired", decided_at: Time.current)
        AuditEvent.create!(
          account_id: proposal.business_profile.account_id,
          action: "change_proposal.expired",
          resource_type: "ChangeProposal",
          resource_id: proposal.id,
          actor_kind: "system",
          metadata: {
            target_kind: proposal.target_kind,
            target_field: proposal.target_field,
            reason: "auto_expire_24h"
          },
          occurred_at: Time.current
        )
        expired_count += 1
      end
    end

    Rails.logger.info("[P2-3] Expired #{expired_count} pending proposals")
    expired_count
  end
end