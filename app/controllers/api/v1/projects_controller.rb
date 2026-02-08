# frozen_string_literal: true

module Api
  module V1
    class ProjectsController < ActionController::API
      before_action :authenticate_master_key!

      # POST /api/v1/projects/provision
      # Creates a new project or returns existing one, linked to Platform
      def provision
        platform_project_id = params[:platform_project_id]
        name = params[:name].to_s.strip

        # If platform_project_id provided, use it as the primary key
        if platform_project_id.present?
          project = Project.find_or_initialize_by(platform_project_id: platform_project_id)
          project.name = name if name.present?
          project.environment = params[:environment] if params[:environment].present?
          project.save!
        elsif name.present?
          # Fallback for standalone mode (no Platform integration)
          project = Project.find_or_initialize_by(name: name)
          project.platform_project_id ||= "pls_#{SecureRandom.hex(8)}"
          project.environment ||= params[:environment] || "development"
          project.save!
        else
          return render json: { error: "Either platform_project_id or name is required" }, status: :bad_request
        end

        # Ensure keys are generated
        ensure_project_keys(project)

        render json: {
          id: project.id,
          platform_project_id: project.platform_project_id,
          name: project.name,
          environment: project.environment,
          api_key: project.settings&.dig("api_key"),
          ingest_key: project.settings&.dig("ingest_key")
        }
      end

      # GET /api/v1/projects/lookup
      # Looks up a project by name or platform_project_id
      def lookup
        project = find_project

        if project
          render json: {
            id: project.id,
            platform_project_id: project.platform_project_id,
            name: project.name,
            environment: project.environment,
            api_key: project.settings&.dig("api_key"),
            ingest_key: project.settings&.dig("ingest_key")
          }
        else
          render json: { error: "Project not found" }, status: :not_found
        end
      end

      private

      def find_project
        if params[:platform_project_id].present?
          Project.find_by(platform_project_id: params[:platform_project_id])
        else
          Project.find_by(name: params[:name])
        end
      end

      def ensure_project_keys(project)
        return unless project.respond_to?(:settings) && project.settings.is_a?(Hash)

        changed = false
        project.settings["api_key"] ||= begin
          changed = true
          "pls_api_#{SecureRandom.hex(24)}"
        end
        project.settings["ingest_key"] ||= begin
          changed = true
          "pls_ingest_#{SecureRandom.hex(24)}"
        end
        project.settings["allowed_origins"] ||= []

        project.save! if changed || project.settings_changed?
      end

      def authenticate_master_key!
        key = request.headers["X-Master-Key"]
        expected = ENV["PULSE_MASTER_KEY"]

        return if key.present? && expected.present? && ActiveSupport::SecurityUtils.secure_compare(key, expected)

        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
