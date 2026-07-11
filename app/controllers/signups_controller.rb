class SignupsController < ApplicationController
  # 회원가입: IP당 3회/시간 (봇 가입 방지)
  rate_limit to: 3, within: 1.hour, only: :create, by: -> { request.remote_ip }, with: -> {
    flash[:alert] = "가입 시도가 너무 많습니다. 잠시 후 다시 시도해주세요."
    render :new, status: :too_many_requests
  }

  def new
    @signup = SignupForm.new
  end

  def create
    @signup = SignupForm.new(signup_params)
    if @signup.save
      session_user = @signup.user
      token = SecureRandom.hex(32)
      Session.create!(user: session_user, token_hash: token, ip_address: request.remote_ip, user_agent: "web_signup", last_seen_at: Time.current, expires_at: 30.days.from_now)
      cookies.signed[:workmori_user_token] = { value: token, httponly: true, expires: 30.days.from_now, same_site: :lax }
      redirect_to app_root_path, notice: "가입이 완료되었습니다. 운영자 검수 후 공식 채널을 열어드립니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:signup).permit(:business_name, :industry_slug, :owner_name, :email, :phone, :password, :password_confirmation, :terms_accepted, :marketing_consent)
  end

  class SignupForm
    include ActiveModel::Model
    attr_accessor :business_name, :industry_slug, :owner_name, :email, :phone, :password, :password_confirmation, :terms_accepted, :marketing_consent

    validates :business_name, :owner_name, :email, presence: true
    validates :terms_accepted, acceptance: true
    validates :password, length: { minimum: 8 }, if: -> { password.present? }
    validate  :email_unique_in_account

    def save
      return false unless valid?
      ApplicationRecord.transaction do
        @account = Account.create!(name: business_name, slug: slugify(business_name), status: "active", operator_managed: true, settings_json: { onboarding_state: "self_signup", consents: { marketing: !!marketing_consent } })
        @user = User.create!(account: @account, email_address: email, name: owner_name, role: "owner", password: password, password_confirmation: password_confirmation, locale: "ko")
        Membership.create!(user: @user, account: @account, role: "owner")
        if industry_slug.present?
          template = IndustryTemplate.find_by(slug: industry_slug)
          if template
            BusinessProfile.create!(
              account: @account,
              industry_code: template.industry_kind,            # BusinessProfile stores a category code (e.g. "beauty")
              industry_subcategory: template.industry_code,       # and the sub-category (e.g. "skincare")
              legal_name: business_name,
              trade_name: business_name,
              owner_name: owner_name,
              phone: phone,
              timezone: "Asia/Seoul",
              operator_managed: true
            )
          end
        end
      end
      true
    end

    def user; @user; end

    private

    def email_unique_in_account
      return unless email
      if User.where(email_address: email).exists?
        errors.add(:email, "이미 등록된 이메일입니다")
      end
    end

    def slugify(s)
      s.to_s.parameterize.gsub(/[^a-z0-9\-]/, "").presence || SecureRandom.hex(4)
    end
  end
end
