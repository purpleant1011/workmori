module Platform
  class FeatureFlagsController < BaseController
    def index; @flags = FeatureFlag.order(:key); end

    def show; @flag = FeatureFlag.find(params[:id]); end

    def new
      @flag = FeatureFlag.new
    end

    def create
      @flag = FeatureFlag.new(flag_params)
      if @flag.save
        redirect_to platform_feature_flags_path, notice: "기능 플래그가 생성되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @flag = FeatureFlag.find_by(key: params[:id]) || FeatureFlag.find(params[:id])
    end

    def update
      flag = FeatureFlag.find_by(key: params[:id]) || FeatureFlag.find(params[:id])
      if flag.update(flag_params)
        redirect_to platform_feature_flags_path, notice: "기능 플래그가 저장되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      flag = FeatureFlag.find_by(key: params[:id]) || FeatureFlag.find(params[:id])
      flag.destroy
      redirect_to platform_feature_flags_path, notice: "기능 플래그가 삭제되었습니다."
    end

    private
    def flag_params
      params.require(:feature_flag).permit(:key, :enabled, :value, :description)
    end
  end
end