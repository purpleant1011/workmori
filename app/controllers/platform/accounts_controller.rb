module Platform
  class AccountsController < BaseController
    def index
      @accounts = Account.order(created_at: :desc).limit(200)
    end

    def show
      @account = Account.find(params[:id])
    end

    def new
      @account = Account.new
    end

    def create
      @account = Account.new(account_params)
      if @account.save
        redirect_to platform_account_path(@account), notice: "계정이 생성되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @account = Account.find(params[:id])
    end

    def update
      @account = Account.find(params[:id])
      if @account.update(account_params)
        redirect_to platform_account_path(@account), notice: "계정을 업데이트했습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @account = Account.find(params[:id])
      @account.destroy
      redirect_to platform_accounts_path, notice: "계정이 삭제되었습니다."
    end

    private
    def account_params
      params.require(:account).permit(:status, :slug, :name, :operator_managed, :settings_json)
    end
  end
end