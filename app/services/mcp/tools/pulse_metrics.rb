module Mcp
  module Tools
    class PulseMetrics < Base
      DESCRIPTION = "Get custom metrics. List available metrics or query a specific one."

      SCHEMA = {
        type: "object",
        properties: {
          name: { type: "string", description: "Metric name (omit to list all)" },
          since: { type: "string", default: "1h" }
        }
      }.freeze

      def call(args)
        if args[:name]
          metric = @project.metrics.find_by!(name: args[:name])
          since = parse_since(args[:since] || '1h')

          {
            metric: {
              name: metric.name,
              kind: metric.kind,
              unit: metric.unit
            },
            stats: metric.stats(since: since)
          }
        else
          {
            metrics: @project.metrics.map { |m|
              { name: m.name, kind: m.kind, unit: m.unit }
            }
          }
        end
      rescue ActiveRecord::RecordNotFound
        { error: "Metric not found" }
      end
    end
  end
end
