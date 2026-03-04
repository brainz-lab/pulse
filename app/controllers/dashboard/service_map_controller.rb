module Dashboard
  class ServiceMapController < BaseController
    def show
      @since = parse_since(params[:since] || "1h")
      @nodes, @edges = build_service_graph
    end

    private

    def build_service_graph
      nodes = {}
      edges = []

      # Current service
      nodes["pulse"] = { name: current_project.name || "This App", type: "app", rpm: 0, avg_ms: 0 }

      # External HTTP calls from spans
      http_stats = current_project.spans
        .joins(:trace)
        .where(traces: { started_at: @since.. })
        .where(spans: { kind: "http" })
        .where.not("spans.data->>'host' IS NULL")
        .group("spans.data->>'host'")
        .select(
          "spans.data->>'host' as host",
          "COUNT(*) as call_count",
          "AVG(spans.duration_ms) as avg_duration",
          "SUM(CASE WHEN spans.error THEN 1 ELSE 0 END) as error_count"
        )

      http_stats.each do |stat|
        host = stat.host
        next if host.blank?
        nodes[host] = { name: host, type: "external", rpm: stat.call_count, avg_ms: stat.avg_duration&.round(1) }
        edges << { from: "pulse", to: host, calls: stat.call_count, avg_ms: stat.avg_duration&.round(1),
                   error_rate: stat.call_count > 0 ? (stat.error_count.to_f / stat.call_count * 100).round(1) : 0 }
      end

      # Database calls
      db_stats = current_project.spans.joins(:trace)
        .where(traces: { started_at: @since.. }).where("spans.kind LIKE 'db%'")
      db_count = db_stats.count
      if db_count > 0
        avg_db = db_stats.average(:duration_ms)
        nodes["database"] = { name: "Database", type: "database", rpm: db_count, avg_ms: avg_db&.round(1) }
        edges << { from: "pulse", to: "database", calls: db_count, avg_ms: avg_db&.round(1), error_rate: 0 }
      end

      # Cache calls
      cache_stats = current_project.spans.joins(:trace)
        .where(traces: { started_at: @since.. }).where("spans.kind LIKE 'cache%'")
      cache_count = cache_stats.count
      if cache_count > 0
        avg_cache = cache_stats.average(:duration_ms)
        nodes["cache"] = { name: "Cache (Redis)", type: "cache", rpm: cache_count, avg_ms: avg_cache&.round(1) }
        edges << { from: "pulse", to: "cache", calls: cache_count, avg_ms: avg_cache&.round(1), error_rate: 0 }
      end

      [ nodes, edges ]
    end

    def parse_since(value)
      case value
      when "6h" then 6.hours.ago
      when "24h" then 24.hours.ago
      when "7d" then 7.days.ago
      else 1.hour.ago
      end
    end
  end
end
