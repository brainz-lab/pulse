module Mcp
  module Tools
    class PulseThroughput < Base
      DESCRIPTION = "Get request throughput over time (requests per minute)."

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h", description: "Time range" },
          granularity: { type: "string", enum: [ "minute", "hour" ], default: "minute" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || "1h")
        granularity = args[:granularity] || "minute"

        data = @project.traces
          .requests
          .where("started_at >= ?", since)
          .group("date_trunc('#{granularity}', started_at)")
          .count
          .sort
          .map { |bucket, count| { time: bucket, count: count } }

        {
          throughput: data,
          granularity: granularity,
          total: data.sum { |d| d[:count] }
        }
      end
    end
  end
end
