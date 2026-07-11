class Public::BaseController < ApplicationController
  layout "public"
  before_action :track_visit

  private

  def track_visit
    AuditEvent.create!(
      account: nil,
      platform_staff: nil,
      action: "page.visit",
      actor_kind: "anon",
      resource_type: controller_path,
      resource_id: nil,
      payload_json: { controller: controller_path, action: action_name, ua: request.user_agent.to_s[0, 200], ip: request.remote_ip },
      occurred_at: Time.current
    ) rescue nil
  end
end
