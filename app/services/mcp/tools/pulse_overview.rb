module Mcp
  module Tools
    class PulseOverview < Base
      DESCRIPTION = "Get application health overview: Apdex score, throughput, " \
        "response times (avg, p95, p99), and error rate."

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h", description: "Time range (1h, 24h, 7d)" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || "1h")
        @project.overview(since: since)
      end
    end
  end
end
