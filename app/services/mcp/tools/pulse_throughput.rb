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

      ALLOWED_GRANULARITIES = %w[minute hour].freeze

      def call(args)
        since = parse_since(args[:since] || "1h")
        granularity = ALLOWED_GRANULARITIES.include?(args[:granularity]) ? args[:granularity] : "minute"

        data = @project.traces
          .requests
          .where("started_at >= ?", since)
          .group(Arel.sql("date_trunc(#{ActiveRecord::Base.connection.quote(granularity)}, started_at)"))
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
