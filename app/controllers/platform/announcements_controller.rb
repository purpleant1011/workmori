# frozen_string_literal: true

# Platform 운영자가 공지 작성/관리 (전역 또는 특정 account 대상)
class Platform::AnnouncementsController < BaseController
  before_action :load_announcement, only: [:show, :edit, :update, :destroy, :publish, :archive]

  def index
    @announcements = Announcement.recent.limit(100)
  end

  def show
  end

  def new
    @announcement = Announcement.new(audience: "all", kind: "info", status: "draft")
  end

  def create
    @announcement = Announcement.new(announcement_params)
    @announcement.created_by_platform_staff = current_platform_staff
    if @announcement.save
      AuditEvent.create!(
        action: "announcement.created",
        resource_type: "Announcement",
        resource_id: @announcement.id,
        metadata: { kind: @announcement.kind, audience: @announcement.audience, account_id: @announcement.account_id },
        occurred_at: Time.current
      )
      redirect_to platform_announcement_path(@announcement), notice: "공지를 작성했습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @announcement.update(announcement_params)
      redirect_to platform_announcement_path(@announcement), notice: "공지를 수정했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @announcement.destroy
    redirect_to platform_announcements_path, notice: "공지를 삭제했습니다."
  end

  def publish
    @announcement.publish!
    AuditEvent.create!(action: "announcement.published", resource_type: "Announcement", resource_id: @announcement.id, occurred_at: Time.current)
    NotificationBroadcaster.platform_event("announcement.published", { id: @announcement.id, title: @announcement.title, audience: @announcement.audience })
    redirect_to platform_announcements_path, notice: "공지 게시 완료. 사업자에게 알림이 전송됩니다."
  end

  def archive
    @announcement.archive!
    redirect_to platform_announcements_path, notice: "공지를 보관했습니다."
  end

  private

  def load_announcement
    @announcement = Announcement.find(params[:id])
  end

  def announcement_params
    params.require(:announcement).permit(
      :account_id, :kind, :title, :body, :audience, :status,
      :published_at, :priority
    )
  end
end