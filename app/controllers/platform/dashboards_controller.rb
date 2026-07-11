module Platform
  class DashboardsController < BaseController
    def show
      @counts = {
        accounts: Account.count,
        staff: PlatformStaff.count,
        industries: IndustryTemplate.count,
        inquiries: Inquiry.count,
        open_inquiries: Inquiry.where(status: "open").count,
        contracts_active: ContractTerm.where(status: "active").count
      }
      @recent_inquiries = Inquiry.order(created_at: :desc).limit(10)
      @recent_signups   = Account.order(created_at: :desc).limit(10)
    end
  end
end
