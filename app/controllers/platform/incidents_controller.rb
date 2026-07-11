module Platform
  class IncidentsController < BaseController
    def index; @incidents = Incident.order(created_at: :desc).limit(100); end
    def show;  @incident  = Incident.find(params[:id]); end

    def new
      @incident = Incident.new(severity: "sev3", state: "open")
    end

    def create
      @incident = Incident.new(incident_params)
      if @incident.save
        redirect_to platform_incident_path(@incident), notice: "인시던트가 등록되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @incident = Incident.find(params[:id])
    end

    def update
      @incident = Incident.find(params[:id])
      if @incident.update(incident_params)
        redirect_to platform_incidents_path, notice: "인시던트 업데이트됨."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @incident = Incident.find(params[:id])
      @incident.destroy
      redirect_to platform_incidents_path, notice: "인시던트가 삭제되었습니다."
    end

    private
    def incident_params
      params.require(:incident).permit(:title, :description, :severity, :state, :resolved_at)
    end
  end
end