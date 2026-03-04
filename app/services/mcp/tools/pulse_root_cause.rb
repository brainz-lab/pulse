module Mcp
  module Tools
    class PulseRootCause < Base
      DESCRIPTION = "Automated root cause analysis: identifies top affected endpoints, slowest spans, problematic queries for a given symptom"

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h" },
          symptom: { type: "string", enum: ["high_latency", "high_errors", "low_apdex"],
                     description: "The symptom to investigate" }
        },
        required: ["symptom"]
      }.freeze

      def call(args)
        since = parse_since(args[:since])
        scope = @project.traces.where("started_at >= ?", since).where(kind: "request")

        case args[:symptom]
        when "high_latency"
          analyze_latency(scope, since)
        when "high_errors"
          analyze_errors(scope, since)
        when "low_apdex"
          analyze_apdex(scope, since)
        end
      end

      private

      def analyze_latency(scope, since)
        slow_endpoints = scope.where.not(duration_ms: nil)
          .group(:name).select("name, AVG(duration_ms) as avg_ms, COUNT(*) as cnt")
          .order("avg_ms DESC").limit(5).map { |r| { endpoint: r.name, avg_ms: r.avg_ms.round(1), count: r.cnt } }

        slow_spans = @project.spans.joins(:trace).where(traces: { started_at: since.. })
          .where.not(duration_ms: nil).order(duration_ms: :desc).limit(10)
          .pluck(:name, :kind, :duration_ms)
          .map { |n, k, d| { name: n, kind: k, duration_ms: d } }

        { symptom: "high_latency", top_slow_endpoints: slow_endpoints, slowest_spans: slow_spans }
      end

      def analyze_errors(scope, since)
        error_endpoints = scope.where(error: true)
          .group(:name).select("name, COUNT(*) as cnt")
          .order("cnt DESC").limit(5).map { |r| { endpoint: r.name, error_count: r.cnt } }

        error_classes = scope.where(error: true).where.not(error_class: nil)
          .group(:error_class).order("count_all DESC").limit(5).count
          .map { |cls, cnt| { error_class: cls, count: cnt } }

        { symptom: "high_errors", top_error_endpoints: error_endpoints, top_error_classes: error_classes }
      end

      def analyze_apdex(scope, since)
        threshold_ms = @project.apdex_t * 1000
        frustrated = scope.where("duration_ms > ?", threshold_ms * 4)
          .group(:name).select("name, COUNT(*) as cnt, AVG(duration_ms) as avg_ms")
          .order("cnt DESC").limit(5)
          .map { |r| { endpoint: r.name, frustrated_count: r.cnt, avg_ms: r.avg_ms.round(1) } }

        { symptom: "low_apdex", threshold_ms: threshold_ms, top_frustrated_endpoints: frustrated }
      end
    end
  end
end
