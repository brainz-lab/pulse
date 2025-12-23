module Api
  module V1
    class TracesController < BaseController
      # POST /api/v1/traces
      def create
        trace = TraceProcessor.new(
          project: current_project,
          payload: trace_params.to_h
        ).process!

        track_usage!(1)

        render json: {
          id: trace.id,
          trace_id: trace.trace_id
        }, status: :created
      end

      # POST /api/v1/traces/batch
      def batch
        traces_data = params[:traces] || params[:_json] || []
        results = []

        traces_data.each do |trace_payload|
          # Permit all necessary trace parameters
          permitted = trace_payload.permit(
            :trace_id, :name, :kind,
            :started_at, :ended_at, :duration_ms,
            :request_id, :request_method, :request_path, :controller, :action, :status,
            :view_ms, :db_ms, :external_ms, :cache_ms,
            :job_class, :job_id, :queue,
            :environment, :commit, :host, :user_id,
            :error, :error_class, :error_message,
            spans: [:span_id, :parent_span_id, :name, :kind, :started_at, :ended_at, :duration_ms, :error, :error_class, :error_message, data: {}]
          )

          trace = TraceProcessor.new(
            project: current_project,
            payload: permitted.to_h
          ).process!

          results << { id: trace.id, trace_id: trace.trace_id }
        end

        track_usage!(results.size)

        render json: { processed: results.size, results: results }, status: :created
      end

      # GET /api/v1/traces
      def index
        traces = current_project.traces.recent

        traces = traces.where(kind: params[:kind]) if params[:kind]
        traces = traces.where(controller: params[:controller]) if params[:controller]
        traces = traces.slow(params[:slow].to_f) if params[:slow]
        traces = traces.errors if params[:errors] == 'true'

        if params[:since]
          since = Time.parse(params[:since]) rescue nil
          traces = traces.where('started_at >= ?', since) if since
        end

        traces = traces.limit(params[:limit] || 50)

        render json: { traces: traces.as_json(except: [:created_at, :updated_at]) }
      end

      # GET /api/v1/traces/:id
      def show
        trace = current_project.traces.find(params[:id])

        render json: {
          trace: trace,
          spans: trace.waterfall
        }
      end

      private

      def trace_params
        params.permit(
          :trace_id, :name, :kind,
          :started_at, :ended_at, :duration_ms,
          :request_id, :request_method, :request_path, :controller, :action, :status,
          :view_ms, :db_ms, :external_ms, :cache_ms,
          :job_class, :job_id, :queue,
          :environment, :commit, :host, :user_id,
          :error, :error_class, :error_message,
          spans: [:span_id, :parent_span_id, :name, :kind, :started_at, :ended_at, :duration_ms, :error, :error_class, :error_message, data: {}]
        )
      end
    end
  end
end
