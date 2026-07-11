# frozen_string_literal: true

module App
  class DataExportsController < BaseController
    skip_before_action :verify_authenticity_token, only: [:create, :destroy]
    def index
      @exports = @current_account.data_export_requests.order(requested_at: :desc).limit(50)
      @kinds   = DataExportRequest.kinds_for(@current_account)
      @formats = DataExportRequest::FORMATS
    end

    def show
      @export  = @current_account.data_export_requests.find(params[:id])
      @kinds   = DataExportRequest.kinds_for(@current_account)
    end

    def create
      kind   = params[:kind].presence   || "full"
      format = params[:format].presence || "json"

      unless DataExportRequest::KINDS.include?(kind)
        return redirect_to(app_data_exports_path, alert: "지원하지 않는 내보내기 종류입니다.")
      end
      unless DataExportRequest::FORMATS.include?(format)
        return redirect_to(app_data_exports_path, alert: "지원하지 않는 파일 형식입니다.")
      end

      filters = {}
      filters["from"] = parse_time(params[:from])
      filters["to"]   = parse_time(params[:to])

      req = DataExportRequest.create!(
        account: @current_account,
        requested_by_user_id: current_user.id,
        requested_at: Time.current,
        state: "pending",
        kind: kind,
        format: format,
        filters_hash: filters,
        expires_at: 30.days.from_now
      )

      DataExportJob.perform_later(req.id)

      redirect_to app_data_exports_path, notice: "데이터 내보내기 요청이 등록되었습니다. (##{req.id})"
    end

    def download
      req = @current_account.data_export_requests.find(params[:id])
      unless req.downloadable?
        redirect_to(app_data_export_path(req), alert: "다운로드할 수 없는 내보내기입니다. (상태: #{req.state})")
        return
      end

      unless File.exist?(req.storage_path)
        req.update!(state: "failed", error_message: "파일을 찾을 수 없습니다.")
        redirect_to(app_data_export_path(req), alert: "파일이 사라졌습니다. 다시 내보내기 요청해주세요.")
        return
      end

      type =
        case req.format
        when "json" then "application/json"
        when "csv"  then "application/zip"
        when "zip"  then "application/zip"
        else "application/octet-stream"
        end

      send_file req.storage_path,
                filename: req.filename,
                type: type,
                disposition: "attachment"

      AuditEvent.create!(
        account_id: @current_account.id,
        actor_user_id: current_user.id,
        action: "data_export.downloaded",
        resource_type: "DataExportRequest",
        resource_id: req.id,
        metadata: { format: req.format, kind: req.kind, size: req.file_size_bytes },
        occurred_at: Time.current
      )
    end

    def destroy
      req = @current_account.data_export_requests.find(params[:id])
      if req.storage_path.present? && File.exist?(req.storage_path)
        File.delete(req.storage_path)
      end
      req.update!(state: "expired", storage_path: nil)
      redirect_to app_data_exports_path, notice: "내보내기 ##{req.id}를 삭제했습니다."
    end

    private

    def parse_time(value)
      return nil if value.blank?
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end