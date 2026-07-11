module Platform
  class ModelCatalogEntriesController < BaseController
    def index; @catalog = ModelCatalogEntry.order(:code); end
    def show;  @entry   = ModelCatalogEntry.find(params[:id]); end

    def new
      @entry = ModelCatalogEntry.new
    end

    def create
      @entry = ModelCatalogEntry.new(catalog_params)
      if @entry.save
        redirect_to platform_model_catalog_entry_path(@entry), notice: "모델 카탈로그가 생성되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @entry = ModelCatalogEntry.find(params[:id])
    end

    def update
      e = ModelCatalogEntry.find(params[:id])
      if e.update(catalog_params)
        redirect_to platform_model_catalog_entry_path(e), notice: "모델 카탈로그 업데이트됨."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      e = ModelCatalogEntry.find(params[:id])
      e.destroy
      redirect_to platform_model_catalog_entries_path, notice: "모델 카탈로그가 삭제되었습니다."
    end

    private
    def catalog_params
      params.require(:model_catalog_entry).permit(:active, :api_model_name, :context_window, :max_output_tokens)
    end
  end
end