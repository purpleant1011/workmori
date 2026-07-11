module App
  class ChannelsController < BaseController
    def index
      @channels = @current_account.channel_connections.includes(:channel_scopes, :ai_employee).order(:kind)
    end

    def show
      @channel = @current_account.channel_connections.find(params[:id])
    end

    def edit
      @channel = @current_account.channel_connections.find(params[:id])
    end

    def update
      @channel = @current_account.channel_connections.find(params[:id])
      if @channel.update(channel_params)
        redirect_to app_channel_path(@channel), notice: "채널 정보가 업데이트되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def new
      @channel = @current_account.channel_connections.build
    end

    def create
      @channel = @current_account.channel_connections.build(channel_params)
      @channel.connected_by_user = current_user
      @channel.connected_by_kind = "owner"
      @channel.status = "ready"
      @channel.connected_by_user_id ||= current_user&.id
      if @channel.save
        redirect_to app_channels_path, notice: "채널이 연결되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def activate
      channel = @current_account.channel_connections.find(params[:id])
      res = Channels::Adapter.verify(channel: channel)
      if res.ok
        channel.update!(status: "active", last_verified_at: Time.current)
        redirect_to app_channels_path, notice: "채널 활성화: #{channel.kind}"
      else
        channel.update!(status: "error", error_message: res.payload.to_json)
        redirect_to app_channels_path, alert: "채널 활성화 실패"
      end
    end

    def pause
      channel = @current_account.channel_connections.find(params[:id])
      channel.update!(status: "paused")
      redirect_to app_channels_path, notice: "채널이 일시정지되었습니다."
    end

    def resume
      channel = @current_account.channel_connections.find(params[:id])
      channel.update!(status: "active")
      redirect_to app_channels_path, notice: "채널이 재개되었습니다."
    end

    def destroy
      channel = @current_account.channel_connections.find(params[:id])
      channel.update!(status: "revoked")
      redirect_to app_channels_path, notice: "채널 연결이 해제되었습니다."
    end

    private

    def channel_params
      params.require(:channel_connection).permit(:kind, :handle, :external_id, :ai_employee_id)
    end
  end
end