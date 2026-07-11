module Public
  class ErrorsController < BaseController
    layout "public"
    def forbidden; render plain: "권한이 없습니다", status: :forbidden; end
    def not_found; render plain: "페이지를 찾을 수 없습니다", status: :not_found; end
    def server_error; render plain: "서버에 일시적인 문제가 발생했습니다", status: :internal_server_error; end
  end
end
