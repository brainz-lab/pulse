module Dashboard
  class BaseController < ApplicationController
    include Pagy::Backend

    before_action :authenticate_via_sso!
    before_action :set_project

    layout "dashboard"

    helper_method :current_project, :pagy_nav

    private

    def authenticate_via_sso!
      # In development, allow bypass
      if Rails.env.development?
        # Use platform project with data for testing, or dev_project for empty state
        session[:platform_project_id] ||= "pls_0147cca1bda98caf"  # platform project with traces
        session[:platform_user_id] ||= "dev_user"
        return
      end

      unless session[:platform_project_id]
        redirect_to "#{platform_url}/auth/sso?product=pulse&return_to=#{request.url}"
      end
    end

    def set_project
      @project = Project.find_or_create_for_platform!(
        platform_project_id: session[:platform_project_id] || "dev_project",
        name: session[:project_name] || "Development Project"
      )
    end

    def current_project
      @project
    end

    def platform_url
      ENV["BRAINZLAB_PLATFORM_URL"] || "http://localhost:2999"
    end
  end
end
