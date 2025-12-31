module Mcp
  module Tools
    class PulseSlowRequests < Base
      DESCRIPTION = "Get slowest requests. Useful for finding performance bottlenecks."

      SCHEMA = {
        type: "object",
        properties: {
          threshold_ms: { type: "number", default: 1000, description: "Min duration in ms" },
          since: { type: "string", default: "1h", description: "Time range" },
          limit: { type: "integer", default: 20, description: "Max results" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || "1h")
        threshold = args[:threshold_ms] || 1000
        limit = args[:limit] || 20

        traces = @project.traces
          .requests
          .where("started_at >= ?", since)
          .where("duration_ms >= ?", threshold)
          .order(duration_ms: :desc)
          .limit(limit)

        {
          slow_requests: traces.map { |t| format_trace(t) },
          threshold_ms: threshold,
          count: traces.size
        }
      end

      private

      def format_trace(trace)
        {
          id: trace.id,
          name: trace.name,
          duration_ms: trace.duration_ms,
          started_at: trace.started_at,
          controller: trace.controller,
          action: trace.action,
          status: trace.status,
          db_ms: trace.db_duration_ms,
          view_ms: trace.view_duration_ms,
          span_count: trace.span_count
        }
      end
    end
  end
end
