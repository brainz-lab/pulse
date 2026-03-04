module Mcp
  module Tools
    class PulseCompare < Base
      DESCRIPTION = "Compare performance metrics between two time periods to detect regressions or improvements"

      SCHEMA = {
        type: "object",
        properties: {
          period_a: { type: "string", description: "First period (e.g., '1h')", default: "1h" },
          period_b: { type: "string", description: "Second period for comparison (e.g., '24h')" },
          endpoint: { type: "string", description: "Optional: specific endpoint to compare" }
        },
        required: ["period_a", "period_b"]
      }.freeze

      def call(args)
        since_a = parse_since(args[:period_a])
        since_b = parse_since(args[:period_b])

        metrics_a = compute_metrics(since_a, args[:endpoint])
        metrics_b = compute_metrics(since_b, args[:endpoint])

        deltas = {}
        metrics_a.each do |key, val_a|
          val_b = metrics_b[key]
          next unless val_a && val_b && val_b != 0
          deltas[key] = { current: val_a, previous: val_b,
                          change_pct: ((val_a - val_b).to_f / val_b * 100).round(2) }
        end

        { period_a: args[:period_a], period_b: args[:period_b], metrics: deltas }
      end

      private

      def compute_metrics(since, endpoint = nil)
        scope = @project.traces.where("started_at >= ?", since).where(kind: "request")
        scope = scope.where(name: endpoint) if endpoint.present?
        total = scope.count
        return {} if total == 0

        stats = scope.where.not(duration_ms: nil).pick(
          Arel.sql("AVG(duration_ms)"),
          Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)"),
          Arel.sql("PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)")
        )

        error_count = scope.where(error: true).count
        {
          throughput: total,
          avg_duration: stats[0]&.round(2),
          p95: stats[1]&.round(2),
          p99: stats[2]&.round(2),
          error_rate: (error_count.to_f / total * 100).round(2)
        }
      end
    end
  end
end
