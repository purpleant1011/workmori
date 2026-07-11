module Platform
  class ContractsController < BaseController
    def index; @contracts = ContractTerm.order(created_at: :desc).limit(200); end
    def show;  @contract  = ContractTerm.find(params[:id]); end
    def new
      @contract = ContractTerm.new(account: Account.first, status: "test_started", test_started_on: Time.zone.today)
    end
    def create
      @contract = ContractTerm.new(contract_params)
      @contract.start_date ||= Time.zone.today
      @contract.save!
      redirect_to platform_contract_path(@contract), notice: "계약이 생성되었습니다."
    end
    def update
      @contract = ContractTerm.find(params[:id])
      @contract.update(contract_params)
      redirect_to platform_contract_path(@contract), notice: "계약이 업데이트되었습니다."
    end
    private
    def contract_params
      params.require(:contract_term).permit(
        :account_id, :plan_id, :contract_code, :monthly_price_krw, :monthly_price_vat_krw,
        :deposit_amount_krw, :billing_anchor_day, :test_started_on, :test_ends_on,
        :official_service_started_on, :status, :notes, :price_overrides
      )
    end
  end
end
