module App
  class ProductsController < BaseController
    before_action :load_product, only: [:show, :edit, :update, :destroy]

    def index
      @products = @current_account.products.order(:name).limit(200)
    end

    def show
    end

    def new
      @product = @current_account.products.new(active: true)
    end

    def create
      @product = @current_account.products.new(product_params)
      if @product.save
        redirect_to app_products_path, notice: "상품이 등록되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @product.update(product_params)
        redirect_to app_products_path, notice: "상품이 수정되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product.destroy
      redirect_to app_products_path, notice: "상품이 삭제되었습니다."
    end

    private

    def load_product
      @product = @current_account.products.find(params[:id])
    end

    def product_params
      params.require(:product).permit(:name, :description, :base_price_krw, :duration_min, :active)
    end
  end
end