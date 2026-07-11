# frozen_string_literal: true
module App
  # "확인할 일" 통합 페이지 (P0-6).
  # 사업자에게 한 화면에서 모든 검토/승인 대기 항목을 보여준다:
  # 1) 사람 인계 (Handoff) — 응대가 사람 확인 필요한 항목
  # 2) 콘텐츠 검수 (ContentItem pending_for_review) — 발행 전 검토
  # Knowledge Gap은 운영자 콘솔에서만 본다 (사업자 노출 금지 정책).
  class ConfirmationsController < App::BaseController
    def index
      @handoffs_open = @current_account.handoffs
                                     .where(state: %w[open acknowledged])
                                     .order(created_at: :desc)
                                     .limit(20)

      @pending_contents = @current_account.content_items
                                           .pending_for_review
                                           .order(created_at: :desc)
                                           .limit(20)

      # 운영자가 따라볼 수 있도록 메타 표시 (사업자 친화 비-기술용어)
      @counts = {
        handoff_open:        @current_account.handoffs.where(state: "open").count,
        handoff_ack:         @current_account.handoffs.where(state: "acknowledged").count,
        content_review:      @current_account.content_items.pending_for_review.count,
        content_scheduled:   @current_account.content_items.where(state: "scheduled").count
      }
    end
  end
end