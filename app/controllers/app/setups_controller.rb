class App::SetupsController < App::BaseController
  before_action :ensure_account_onboarded

  def show
    @business_profile = @current_account.business_profile || @current_account.build_business_profile
    @step = (@business_profile.onboarding_step || 0).to_i
    @total_steps = 5
  end

  def update
    @business_profile = @current_account.business_profile || @current_account.build_business_profile
    step = params[:step].to_i

    case step
    when 1
      # Step 1: 기본 정보
      @business_profile.update(step1_params)
    when 2
      # Step 2: 브랜드 소개
      @business_profile.update(step2_params)
    when 3
      # Step 3: 영업시간
      @business_profile.update(step3_params)
    when 4
      # Step 4: FAQ
      @business_profile.update(step4_params)
    when 5
      # Step 5: 인계 규칙 + 완료
      @business_profile.update(step5_params)
      @business_profile.update(onboarding_step: 5, onboarding_complete: true)
    end

    redirect_to app_setup_path, notice: "셋업이 저장되었습니다."
  end

  def skip
    @business_profile = @current_account.business_profile || @current_account.build_business_profile
    # 운영팀이 함께 셋업하므로 사업자는 일부 단계를 건너뛸 수 있다.
    flash[:notice] = "건너뛰었습니다. 운영팀이 나머지를 채워 드립니다."
    redirect_to app_setup_path
  end

  private

  def ensure_account_onboarded
    redirect_to root_path unless @current_account
  end

  def step1_params
    params.require(:business_profile).permit(:legal_name, :trade_name, :industry_code, :industry_subcategory, :owner_name, :phone, :public_email, :region_label, :address)
  end

  def step2_params
    params.require(:business_profile).permit(:brand_intro, :target_audience, :differentiators)
  end

  def step3_params
    base = params.require(:business_profile).permit(:holidays_json, business_hours_json: {}).to_h
    base
  end

  def step4_params
    params.require(:business_profile).permit(faqs_json: [:q, :a])
  end

  def step5_params
    params.require(:business_profile).permit(forbidden_phrases_json: [], forbidden_topics_json: [], escalation_rules_json: [])
  end
end