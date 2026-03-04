module Mcp
  module Tools
    class PulseServiceMap < Base
      DESCRIPTION = "Get service dependency map showing external calls, databases, and caches with latency and throughput"

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", description: "Time range (e.g., '1h', '24h', '7d')", default: "1h" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since])
        nodes = {}
        edges = []

        nodes[@project.name || "app"] = { type: "app" }

        # External HTTP dependencies
        @project.spans.joins(:trace)
          .where(traces: { started_at: since.. })
          .where(kind: "http")
          .where.not("spans.data->>'host' IS NULL")
          .group("spans.data->>'host'")
          .select("spans.data->>'host' as host, COUNT(*) as calls, AVG(spans.duration_ms) as avg_ms,
                   SUM(CASE WHEN spans.error THEN 1 ELSE 0 END) as error_count")
          .each do |row|
            nodes[row.host] = { type: "external_service" }
            edges << { from: @project.name, to: row.host, calls: row.calls,
                       avg_ms: row.avg_ms&.round(1), error_rate: (row.error_count.to_f / row.calls * 100).round(1) }
          end

        # DB stats
        db = @project.spans.joins(:trace).where(traces: { started_at: since.. })
          .where("spans.kind LIKE 'db%'")
          .pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(spans.duration_ms)"))
        if db[0]&.positive?
          nodes["database"] = { type: "database" }
          edges << { from: @project.name, to: "database", calls: db[0], avg_ms: db[1]&.round(1) }
        end

        # Cache stats
        cache = @project.spans.joins(:trace).where(traces: { started_at: since.. })
          .where(kind: "cache")
          .pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(spans.duration_ms)"))
        if cache[0]&.positive?
          nodes["cache"] = { type: "cache" }
          edges << { from: @project.name, to: "cache", calls: cache[0], avg_ms: cache[1]&.round(1) }
        end

        { nodes: nodes, edges: edges }
      end
    end
  end
end
