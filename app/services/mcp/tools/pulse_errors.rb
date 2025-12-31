module Mcp
  module Tools
    class PulseErrors < Base
      DESCRIPTION = "Get requests that resulted in errors (5xx status or exceptions)."

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h", description: "Time range" },
          limit: { type: "integer", default: 20 }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || "1h")
        limit = args[:limit] || 20

        traces = @project.traces
          .where("started_at >= ?", since)
          .where(error: true)
          .order(started_at: :desc)
          .limit(limit)

        {
          error_traces: traces.map { |t|
            {
              id: t.id,
              name: t.name,
              error_class: t.error_class,
              error_message: t.error_message&.truncate(200),
              started_at: t.started_at,
              duration_ms: t.duration_ms
            }
          },
          count: traces.size
        }
      end
    end
  end
end
