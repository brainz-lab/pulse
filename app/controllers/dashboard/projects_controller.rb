module Dashboard
  class ProjectsController < BaseController
    before_action :redirect_to_platform_in_production, only: [ :new, :create ]

    def index
      @projects = Project.order(created_at: :desc)
    end

    def new
      @project = Project.new
    end

    def create
      @project = Project.new(project_params)
      @project.platform_project_id ||= "pulse_#{SecureRandom.hex(8)}"

      if @project.save
        session[:platform_project_id] = @project.platform_project_id
        session[:project_name] = @project.name
        redirect_to dashboard_overview_path, notice: "Project created!"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def overview
      select_project
      redirect_to dashboard_overview_path
    end

    private

    def select_project
      project = Project.find(params[:id])
      session[:platform_project_id] = project.platform_project_id
      session[:project_name] = project.name
    end

    def project_params
      params.require(:project).permit(:name, :environment)
    end

    def redirect_to_platform_in_production
      return unless Rails.env.production?

      platform_url = ENV.fetch("BRAINZLAB_PLATFORM_EXTERNAL_URL", "https://platform.brainzlab.ai")
      redirect_to dashboard_projects_path, alert: "Projects are managed in Platform. Visit #{platform_url} to create new projects."
    end
  end
end
