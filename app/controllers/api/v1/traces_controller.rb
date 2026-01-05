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

        # Permit all necessary trace parameters for each payload
        payloads = traces_data.map do |trace_payload|
          trace_payload.permit(
            :trace_id, :name, :kind,
            :started_at, :ended_at, :duration_ms,
            :request_id, :request_method, :request_path, :controller, :action, :status,
            :view_ms, :db_ms, :external_ms, :cache_ms,
            :job_class, :job_id, :queue,
            :environment, :commit, :host, :user_id,
            :error, :error_class, :error_message,
            spans: [ :span_id, :parent_span_id, :name, :kind, :started_at, :ended_at, :duration_ms, :error, :error_class, :error_message, data: {} ]
          ).to_h
        end

        # Use batch processing to avoid N+1 queries
        traces = TraceProcessor.process_batch!(
          project: current_project,
          payloads: payloads
        )

        results = traces.map { |trace| { id: trace.id, trace_id: trace.trace_id } }

        track_usage!(results.size)

        render json: { processed: results.size, results: results }, status: :created
      end

      # GET /api/v1/traces
      def index
        traces = current_project.traces.recent

        # Use filter_* prefix to avoid Rails routing param conflicts (controller/action are reserved)
        traces = traces.where(kind: params[:filter_kind]) if params[:filter_kind].present?
        traces = traces.where(controller: params[:filter_controller]) if params[:filter_controller].present?
        traces = traces.slow(params[:slow].to_f) if params[:slow].present?
        traces = traces.errors if params[:errors] == "true"

        if params[:since].present?
          since = Time.parse(params[:since]) rescue nil
          traces = traces.where("started_at >= ?", since) if since
        end

        traces = traces.limit(params[:limit].presence || 50)

        render json: { traces: traces.as_json(except: [ :created_at, :updated_at ]) }
      end

      # GET /api/v1/traces/:id
      def show
        trace = current_project.traces.find_by!(trace_id: params[:id])

        render json: {
          trace: trace,
          spans: trace.waterfall
        }
      end

      # Signal integration: Query traces with aggregation for alerting
      def query
        metric = params[:metric] || "duration_ms"
        aggregation = params[:aggregation] || "avg"
        window = parse_window(params[:window] || "5m")
        query_filters = JSON.parse(params[:query] || "{}")

        scope = current_project.traces.where("started_at >= ?", window.ago)

        # Apply additional query filters
        query_filters.each do |key, value|
          case key
          when "kind" then scope = scope.where(kind: value)
          when "environment" then scope = scope.where(environment: value)
          when "controller" then scope = scope.where(controller: value)
          when "error" then scope = scope.where(error: value == "true")
          end
        end

        value = case aggregation
        when "avg" then scope.average(metric)&.round(2)
        when "p95"
                  durations = scope.pluck(metric).sort
                  index = (durations.length * 0.95).ceil - 1
                  durations[index] || 0
        when "count" then scope.count
        when "sum" then scope.sum(metric)
        when "min" then scope.minimum(metric)
        when "max" then scope.maximum(metric)
        when "error_rate"
                  total = scope.count
                  errors = scope.where(error: true).count
                  total > 0 ? ((errors.to_f / total) * 100).round(2) : 0
        when "apdex"
                  # Calculate Apdex with T=500ms
                  t = 500.0
                  satisfied = scope.where("duration_ms <= ?", t).count
                  tolerating = scope.where("duration_ms > ? AND duration_ms <= ?", t, t * 4).count
                  total = scope.count
                  total > 0 ? ((satisfied + tolerating * 0.5) / total).round(2) : 1.0
        else
                  scope.average(metric)&.round(2)
        end

        render json: { value: value, metric: metric, window: params[:window] }
      end

      # Signal integration: Get baseline for anomaly detection
      def baseline
        metric = params[:metric] || "duration_ms"
        window = parse_window(params[:window] || "24h")

        scope = current_project.traces.where("started_at >= ?", window.ago)

        # Get hourly averages for the baseline window
        hourly_values = scope.group("date_trunc('hour', started_at)")
                             .average(metric)
                             .values
                             .compact

        if hourly_values.empty?
          render json: { mean: 0, stddev: 1 }
        else
          mean = hourly_values.sum / hourly_values.size
          variance = hourly_values.map { |v| (v - mean)**2 }.sum / hourly_values.size
          stddev = Math.sqrt(variance)

          render json: { mean: mean.round(2), stddev: [ stddev, 1 ].max.round(2) }
        end
      end

      # Signal integration: Get last trace for absence detection
      def last
        metric = params[:metric] || "duration_ms"
        query_filters = JSON.parse(params[:query] || "{}")

        scope = current_project.traces

        query_filters.each do |key, value|
          case key
          when "kind" then scope = scope.where(kind: value)
          when "environment" then scope = scope.where(environment: value)
          end
        end

        last_trace = scope.order(started_at: :desc).first

        if last_trace
          render json: {
            timestamp: last_trace.started_at.iso8601,
            value: last_trace.send(metric),
            name: last_trace.name
          }
        else
          render json: { timestamp: nil, value: nil }
        end
      end

      private

      def parse_window(window_str)
        match = window_str&.match(/^(\d+)(m|h|d)$/)
        return 5.minutes unless match

        value = match[1].to_i
        case match[2]
        when "m" then value.minutes
        when "h" then value.hours
        when "d" then value.days
        else 5.minutes
        end
      end

      def trace_params
        params.permit(
          :trace_id, :name, :kind,
          :started_at, :ended_at, :duration_ms,
          :request_id, :request_method, :request_path, :controller, :action, :status,
          :view_ms, :db_ms, :external_ms, :cache_ms,
          :job_class, :job_id, :queue,
          :environment, :commit, :host, :user_id,
          :error, :error_class, :error_message,
          spans: [ :span_id, :parent_span_id, :name, :kind, :started_at, :ended_at, :duration_ms, :error, :error_class, :error_message, data: {} ]
        )
      end
    end
  end
end
