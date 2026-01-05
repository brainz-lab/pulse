module Api
  module V1
    class SpansController < BaseController
      # POST /api/v1/spans
      # Standalone span ingestion (used by brainzlab-rails for Rails instrumentation)
      # Creates or attaches to a trace based on request_id
      def create
        # Find or create trace based on request_id
        trace = find_or_create_trace

        span = trace.add_span!(
          span_id: params[:span_id] || SecureRandom.hex(8),
          parent_span_id: params[:parent_span_id],
          name: params[:name],
          kind: params[:category] || params[:kind] || "custom",
          started_at: parse_timestamp(params[:started_at] || params[:timestamp]),
          ended_at: params[:ended_at] ? Time.parse(params[:ended_at]) : nil,
          duration_ms: params[:duration_ms],
          data: build_span_data,
          error: params[:error] || false,
          error_class: params[:error_class],
          error_message: params[:error_message]
        )

        render json: { span_id: span.span_id, trace_id: trace.trace_id }, status: :created
      end

      # POST /api/v1/spans/batch
      # Batch span ingestion for efficiency
      def batch
        spans_data = params[:spans] || []
        created_spans = []

        spans_data.each do |span_params|
          trace = find_or_create_trace_for(span_params)

          span = trace.add_span!(
            span_id: span_params[:span_id] || SecureRandom.hex(8),
            parent_span_id: span_params[:parent_span_id],
            name: span_params[:name],
            kind: span_params[:category] || span_params[:kind] || "custom",
            started_at: parse_timestamp(span_params[:started_at] || span_params[:timestamp]),
            ended_at: span_params[:ended_at] ? Time.parse(span_params[:ended_at]) : nil,
            duration_ms: span_params[:duration_ms],
            data: span_params[:attributes] || span_params[:data] || {},
            error: span_params[:error] || false,
            error_class: span_params[:error_class],
            error_message: span_params[:error_message]
          )

          created_spans << { span_id: span.span_id, trace_id: trace.trace_id }
        end

        render json: { spans: created_spans, count: created_spans.size }, status: :created
      end

      private

      def find_or_create_trace
        find_or_create_trace_for(params)
      end

      def find_or_create_trace_for(span_params)
        request_id = span_params[:request_id]
        trace_id = span_params[:trace_id]

        # Try to find existing trace by trace_id first
        if trace_id.present?
          trace = current_project.traces.find_by(trace_id: trace_id)
          return trace if trace
        end

        # Try to find by request_id, preferring "request" type traces
        if request_id.present?
          # First try to find a request/job trace (primary traces)
          trace = current_project.traces.where(request_id: request_id)
                                        .where(kind: %w[request job])
                                        .first
          return trace if trace

          # Fall back to any trace with this request_id
          trace = current_project.traces.find_by(request_id: request_id)
          return trace if trace
        end

        # Create new trace for this span
        # Use "custom" kind for standalone instrumentation spans
        current_project.traces.create!(
          trace_id: trace_id || SecureRandom.uuid,
          request_id: request_id,
          name: span_params[:name] || "rails.instrumentation",
          kind: "custom",
          environment: span_params[:environment] || current_project.environment || "development",
          host: span_params[:host],
          started_at: parse_timestamp(span_params[:started_at] || span_params[:timestamp]),
          ended_at: nil,
          status: 0
        )
      end

      def build_span_data
        # Merge attributes into data, handling ActionController::Parameters
        data = params[:data].respond_to?(:to_unsafe_h) ? params[:data].to_unsafe_h : (params[:data] || {})
        attributes = params[:attributes].respond_to?(:to_unsafe_h) ? params[:attributes].to_unsafe_h : (params[:attributes] || {})
        data.merge(attributes)
      end

      def parse_timestamp(value)
        return Time.current if value.blank?

        Time.parse(value.to_s)
      rescue ArgumentError
        Time.current
      end
    end
  end
end
