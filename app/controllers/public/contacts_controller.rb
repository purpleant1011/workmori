module Public
  class ContactsController < BaseController
    def new; @contact = Inquiry.new; end

    def create
      @contact = Inquiry.new(contact_params)
      if @contact.save
        Inquiries::ClassifyJob.perform_later(@contact.id)
        redirect_to public_contact_thanks_path, notice: "문의가 접수되었습니다. (가칭 운영자에게 전달)"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def thanks; end

    private

    def contact_params
      params.require(:inquiry).permit(:name, :email, :phone, :subject, :body, :consent_marketing)
    end
  end
end
