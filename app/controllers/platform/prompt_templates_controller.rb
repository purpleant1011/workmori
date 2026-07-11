module Platform
  class PromptTemplatesController < BaseController
    def index; @templates = PromptTemplate.order(:code); end
    def show;  @template  = PromptTemplate.find(params[:id]); end

    def new
      @template = PromptTemplate.new
    end

    def create
      @template = PromptTemplate.new(template_params)
      if @template.save
        redirect_to platform_prompt_template_path(@template), notice: "프롬프트 템플릿이 생성되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @template = PromptTemplate.find(params[:id])
    end

    def update
      t = PromptTemplate.find(params[:id])
      if t.update(template_params)
        redirect_to platform_prompt_template_path(t), notice: "프롬프트 템플릿 업데이트됨."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      t = PromptTemplate.find(params[:id])
      t.destroy
      redirect_to platform_prompt_templates_path, notice: "프롬프트 템플릿이 삭제되었습니다."
    end

    private
    def template_params
      params.require(:prompt_template).permit(:body, :system_prompt, :active)
    end
  end
end