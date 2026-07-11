class App::BusinessProfilesController < App::BaseController
  def show
    @business_profile = @current_account.business_profile || @current_account.build_business_profile
  end

  def edit
    @business_profile = @current_account.business_profile || @current_account.build_business_profile
  end

  def update
    @business_profile = @current_account.business_profile || @current_account.build_business_profile
    if @business_profile.update(business_params)
      redirect_to app_business_profile_path, notice: "회사 정보가 저장되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def business_params
    params.require(:business_profile).permit(
      :legal_name, :trade_name, :industry_code, :industry_subcategory, :owner_name, :phone, :public_email,
      :address, :region_label, :timezone, :brand_intro, :target_audience, :differentiators,
      :onboarding_step, :onboarding_complete, :operator_managed,
      business_hours_json: {}, holidays_json: {}, products_json: [], services_json: [],
      faqs_json: [], customer_anxieties_json: [], forbidden_phrases_json: [], forbidden_topics_json: [],
      escalation_rules_json: [], preferred_channels_json: []
    )
  end
end
