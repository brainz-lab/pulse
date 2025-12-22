module Mcp
  module Tools
    class PulseTrace < Base
      DESCRIPTION = "Get detailed trace with all spans (waterfall view). " \
        "Use to analyze a specific request's performance breakdown."

      SCHEMA = {
        type: "object",
        properties: {
          trace_id: { type: "string", description: "Trace ID" }
        },
        required: ["trace_id"]
      }.freeze

      def call(args)
        trace = @project.traces.find_by!(trace_id: args[:trace_id])

        {
          trace: {
            id: trace.id,
            trace_id: trace.trace_id,
            name: trace.name,
            kind: trace.kind,
            started_at: trace.started_at,
            duration_ms: trace.duration_ms,
            status: trace.status,
            error: trace.error,
            error_class: trace.error_class,
            error_message: trace.error_message,
            db_duration_ms: trace.db_duration_ms,
            view_duration_ms: trace.view_duration_ms,
            external_duration_ms: trace.external_duration_ms
          },
          spans: trace.waterfall
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Trace not found" }
      end
    end
  end
end
