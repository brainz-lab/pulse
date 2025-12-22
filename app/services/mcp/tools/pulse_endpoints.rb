module Mcp
  module Tools
    class PulseEndpoints < Base
      DESCRIPTION = "Get performance stats by endpoint (controller/action). " \
        "Shows which endpoints are slowest or most called."

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h" },
          sort_by: { type: "string", enum: ["count", "avg_duration", "p95"], default: "count" },
          limit: { type: "integer", default: 20 }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '1h')
        limit = args[:limit] || 20

        endpoints = @project.traces
          .requests
          .where('started_at >= ?', since)
          .where.not(duration_ms: nil)
          .group(:name)
          .select(
            'name',
            'COUNT(*) as count',
            'AVG(duration_ms) as avg_duration',
            'MAX(duration_ms) as max_duration',
            'SUM(CASE WHEN error THEN 1 ELSE 0 END) as error_count'
          )

        sorted = case args[:sort_by]
          when 'avg_duration' then endpoints.order('avg_duration DESC')
          when 'p95' then endpoints.order('max_duration DESC')
          else endpoints.order('count DESC')
        end

        {
          endpoints: sorted.limit(limit).map { |e|
            {
              name: e.name,
              count: e.count,
              avg_duration_ms: e.avg_duration.round(2),
              max_duration_ms: e.max_duration,
              error_count: e.error_count,
              error_rate: (e.error_count.to_f / e.count * 100).round(2)
            }
          }
        }
      end
    end
  end
end
