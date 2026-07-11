class App::AiEmployeesController < App::BaseController
  def index
    @employees = @current_account.ai_employees.order(:name)
  end

  def show
    @employee = @current_account.ai_employees.find(params[:id])
    @versions = @employee.ai_employee_versions.order(created_at: :desc).limit(20)
  end

  def edit
    @employee = @current_account.ai_employees.find(params[:id])
  end

  def update
    @employee = @current_account.ai_employees.find(params[:id])
    if @employee.update(employee_params)
      audit_change!(@employee)
      redirect_to app_ai_employee_path(@employee), notice: "AI 직원 설정이 저장되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def employee_params
    params.require(:ai_employee).permit(
      :name, :role_label, :industry_expertise, :tone, :friendliness, :expertise_level, :proactiveness,
      :honorific, :sentence_length, :daily_post_quota, :weekly_post_quota, :approval_mode,
      :monthly_token_budget, :daily_token_budget, :monthly_cost_budget_krw, :daily_cost_budget_krw,
      :natural_language_instructions, :status,
      work_days_json: [], work_hours_json: {},
      vocabulary_phrases_json: [], forbidden_phrases_json: [],
      can_answer_topics_json: [], must_handoff_topics_json: [],
      channel_behaviors_json: {}
    )
  end

  def audit_change!(employee)
    AiEmployeeVersion.create!(
      account: @current_account,
      ai_employee: employee,
      version_number: (employee.ai_employee_versions.maximum(:version_number) || 0) + 1,
      payload_json: employee.attributes,
      natural_language_instructions: employee.natural_language_instructions,
      changed_by: current_user,
      change_summary: "user edit"
    )
  end
end
