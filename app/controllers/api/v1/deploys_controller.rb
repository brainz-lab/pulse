# frozen_string_literal: true

module Api
  module V1
    class DeploysController < BaseController
      # POST /api/v1/deploys
      def create
        deploy = current_project.deploys.create!(
          version: params[:version],
          commit_sha: params[:commit_sha],
          deployed_by: params[:deployed_by],
          environment: params[:environment] || current_project.environment,
          description: params[:description],
          metadata: params[:metadata] || {},
          deployed_at: params[:deployed_at] || Time.current
        )

        render json: { deploy: deploy.as_json(except: [:updated_at]) }, status: :created
      end

      # GET /api/v1/deploys
      def index
        deploys = current_project.deploys.recent

        if params[:since].present?
          since = Time.parse(params[:since]) rescue nil
          deploys = deploys.since(since) if since
        end

        deploys = deploys.limit(params[:limit].presence || 25)

        render json: { deploys: deploys.as_json(except: [:updated_at]) }
      end
    end
  end
end
