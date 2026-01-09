module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!

      attr_reader :current_project

      private

      def authenticate!
        raw_key = extract_api_key
        return render_unauthorized unless raw_key.present?

        # Check if it's a standalone pls_ API key (from auto-provisioning)
        if raw_key.start_with?("pls_")
          @current_project = Project.find_by("settings->>'api_key' = ?", raw_key)
          return if @current_project
        end

        # Try Platform key (sk_live_... or sk_test_...)
        if raw_key.start_with?("sk_live_", "sk_test_")
          @current_project = validate_with_platform(raw_key)
          return if @current_project
        end

        render_unauthorized
      end

      def validate_with_platform(key)
        result = PlatformClient.validate_key(key)
        return nil unless result.valid?

        # Create/sync local project from Platform
        PlatformClient.find_or_create_project(result, key)
      rescue StandardError => e
        Rails.logger.error "[BaseController] Platform validation error: #{e.message}"
        nil
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def extract_api_key
        auth_header = request.headers["Authorization"]
        return auth_header.sub(/^Bearer\s+/, "") if auth_header&.start_with?("Bearer ")
        request.headers["X-API-Key"] || params[:api_key]
      end

      def track_usage!(count = 1)
        return unless @current_project

        PlatformClient.track_usage(
          project_id: @current_project.platform_project_id,
          product: "pulse",
          metric: "traces",
          count: count
        )
      end
    end
  end
end
