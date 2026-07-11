class App::AutomationRulesController < App::BaseController
  def index
    @rules = @current_account.automation_rules.includes(:ai_employee).order(:name)
  end

  def show
    @rule = @current_account.automation_rules.find(params[:id])
    @executions = @rule.automation_executions.order(created_at: :desc).limit(30)
  end

  def new
    @rule = @current_account.automation_rules.build
    @ai_employees = @current_account.ai_employees.order(:name)
    @intents = ContentItem::KINDS if defined?(ContentItem::KINDS)
  end

  def create
    @rule = @current_account.automation_rules.build(rule_params.except(:status))
    @rule.account = @current_account
    @rule.intent_kind ||= "post"
    @rule.status = "active"
    if @rule.save
      sched = @rule.automation_schedules.first || @rule.automation_schedules.build
      sched.account = @current_account
      apply_schedule_from_params(sched)
      sched.save!
      redirect_to app_automation_rule_path(@rule), notice: "자동화 규칙을 생성했습니다."
    else
      flash[:alert] = @rule.errors.full_messages.to_sentence
      redirect_to app_automation_rules_path
    end
  end

  def edit
    @rule = @current_account.automation_rules.find(params[:id])
    @ai_employees = @current_account.ai_employees.order(:name)
    @intents = ContentItem::KINDS if defined?(ContentItem::KINDS)
  end

  def update
    @rule = @current_account.automation_rules.find(params[:id])
    if @rule.update(rule_params)
      @rule.update(status: "active") if @rule.status.blank?
      sched = @rule.automation_schedules.first || @rule.automation_schedules.build
      sched.account = @current_account
      apply_schedule_from_params(sched)
      sched.save!
      redirect_to app_automation_rule_path(@rule), notice: "자동화 규칙을 수정했습니다."
    else
      flash[:alert] = @rule.errors.full_messages.to_sentence
      redirect_to app_automation_rules_path
    end
  end

  def destroy
    @rule = @current_account.automation_rules.find(params[:id])
    @rule.destroy
    redirect_to app_automation_rules_path, notice: "규칙을 삭제했습니다."
  end

  def activate
    @rule = @current_account.automation_rules.find(params[:id])
    @rule.update(status: "active")
    redirect_to app_automation_rule_path(@rule), notice: "규칙을 활성화했습니다."
  end

  def pause
    @rule = @current_account.automation_rules.find(params[:id])
    @rule.update(status: "paused")
    redirect_to app_automation_rule_path(@rule), notice: "규칙을 일시정지했습니다."
  end

  def run_now
    @rule = @current_account.automation_rules.find(params[:id])
    Automation::RunJob.perform_now(automation_rule_id: @rule.id, account_id: @current_account.id)
    redirect_to app_automation_rule_path(@rule), notice: "즉시 실행했습니다."
  rescue StandardError => e
    flash[:alert] = "실행 실패: #{e.message}"
    redirect_to app_automation_rule_path(@rule)
  end

  def dashboard
    @executions = @current_account.automation_executions.order(created_at: :desc).limit(50)
  end

  private

  def apply_schedule_from_params(sched)
    sched.cadence = params[:cadence].presence || sched.cadence || "daily"
    sched.cron_expression = params[:cron_expression] if params[:cron_expression].present?
    sched.next_run_at = sched.compute_next_run_from(Time.current) if sched.respond_to?(:compute_next_run_from) && !sched.next_run_at
  end

  def rule_params
    raw = params[:automation_rule]
    return {} unless raw
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    raw = raw.symbolize_keys if raw.is_a?(Hash)
    raw.reject { |_, v| v.nil? || (v.respond_to?(:blank?) && v.blank?) }
  end
end
