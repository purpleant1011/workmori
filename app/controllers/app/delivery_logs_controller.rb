class App::DeliveryLogsController < App::BaseController
  def index
    @deliveries = @current_account.delivery_logs.order(delivered_at: :desc).limit(50)
  end
end
