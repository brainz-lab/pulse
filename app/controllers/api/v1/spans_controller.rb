module Api
  module V1
    class SpansController < BaseController
      # POST /api/v1/traces/:trace_id/spans
      def create
        trace = current_project.traces.find_by!(trace_id: params[:trace_id])

        span = trace.add_span!(
          span_id: params[:span_id] || SecureRandom.hex(8),
          parent_span_id: params[:parent_span_id],
          name: params[:name],
          kind: params[:kind] || "custom",
          started_at: params[:started_at] ? Time.parse(params[:started_at]) : Time.current,
          ended_at: params[:ended_at] ? Time.parse(params[:ended_at]) : nil,
          duration_ms: params[:duration_ms],
          data: params[:data] || {},
          error: params[:error] || false,
          error_class: params[:error_class],
          error_message: params[:error_message]
        )

        render json: { span_id: span.span_id }, status: :created
      end
    end
  end
end
