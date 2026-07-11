class InquiriesController < ApplicationController
  def index
    require_platform_sign_in!
    @inquiries = Inquiry.order(created_at: :desc).limit(100)
  end

  def show
    require_platform_sign_in!
    @inquiry = Inquiry.find(params[:id])
  end
end
