# frozen_string_literal: true
module App
  # "확인할 일" 통합 페이지 (§7 P1 step 3).
  # 3 탭: 지금 확인 (open) / 운영팀 확인 중 (acknowledged + 진행 중) / 처리 완료 (resolved/done).
  # Knowledge Gap은 운영자 콘솔에서만 본다 (사업자 노출 금지 정책).
  class ConfirmationsController < App::BaseController
    TAB_OPEN   = "open"
    TAB_TEAM   = "team"
    TAB_DONE   = "done"
    ALL_TABS   = [TAB_OPEN, TAB_TEAM, TAB_DONE].freeze

    def index
      @tab = ALL_TABS.include?(params[:tab]) ? params[:tab] : TAB_OPEN

      handoffs_open  = @current_account.handoffs.where(state: %w[open acknowledged]).order(created_at: :desc).limit(20)
      handoffs_team  = @current_account.handoffs.where(state: %w[acknowledged operator_review]).order(updated_at: :desc).limit(20)
      handoffs_done  = @current_account.handoffs.where(state: %w[resolved closed]).order(updated_at: :desc).limit(20)

      contents_review = @current_account.content_items.pending_for_review.order(created_at: :desc).limit(20)
      contents_team   = @current_account.content_items.where(state: %w[in_review team_review]).order(updated_at: :desc).limit(20)
      contents_done   = @current_account.content_items.where(state: %w[published approved archived]).order(updated_at: :desc).limit(20)

      case @tab
      when TAB_OPEN
        @handoffs      = handoffs_open
        @contents      = contents_review
      when TAB_TEAM
        @handoffs      = handoffs_team
        @contents      = contents_team
      when TAB_DONE
        @handoffs      = handoffs_done
        @contents      = contents_done
      end

      @counts = {
        open: handoffs_open.count + contents_review.count,
        team: handoffs_team.count + contents_team.count,
        done: handoffs_done.count + contents_done.count
      }
    end
  end
end