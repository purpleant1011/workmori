module App
  class ReferralsController < BaseController
    def index
      @referrals = @current_account.referrals.order(created_at: :desc).limit(100)
    end

    def create
      link = ReferralLink.create!(account: @current_account, code: SecureRandom.hex(4))
      Referral.create!(account: @current_account, referral_link: link, status: "pending")
      redirect_to referrals_path, notice: "추천 링크가 생성되었습니다."
    end
  end
end
