module Api
  module V1
    class MetricsController < BaseController
      # POST /api/v1/metrics
      def create
        metric = current_project.metrics.find_or_create_by!(name: params[:name]) do |m|
          m.kind = params[:kind] || 'gauge'
          m.unit = params[:unit]
          m.description = params[:description]
        end

        metric.record!(
          params[:value].to_f,
          tags: params[:tags] || {},
          timestamp: params[:timestamp] ? Time.parse(params[:timestamp]) : Time.current
        )

        render json: { metric_id: metric.id }, status: :created
      end

      # POST /api/v1/metrics/batch
      def batch
        metrics_data = params[:metrics] || params[:_json] || []
        count = 0

        metrics_data.each do |m|
          metric = current_project.metrics.find_or_create_by!(name: m[:name]) do |new_m|
            new_m.kind = m[:kind] || 'gauge'
          end

          metric.record!(m[:value].to_f, tags: m[:tags] || {})
          count += 1
        end

        render json: { processed: count }, status: :created
      end

      # GET /api/v1/metrics
      def index
        metrics = current_project.metrics

        render json: { metrics: metrics }
      end

      # GET /api/v1/metrics/:name/stats
      def stats
        metric = current_project.metrics.find_by!(name: params[:name])
        since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago
        granularity = params[:granularity] || 'minute'

        render json: { stats: metric.stats(since: since, granularity: granularity.to_sym) }
      end

      # GET /api/v1/overview
      def overview
        since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago

        render json: current_project.overview(since: since)
      end
    end
  end
end
