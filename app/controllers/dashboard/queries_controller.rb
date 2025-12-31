module Dashboard
  class QueriesController < BaseController
    def index
      @since = parse_since(params[:since])
      @tab = params[:tab] || "n_plus_one"
      @threshold = (params[:threshold] || 100).to_i

      analyzer = QueryAnalyzer.new(project: current_project, since: @since)
      detector = NPlusOneDetector.new(project: current_project, since: @since)

      @summary = analyzer.summary

      case @tab
      when "n_plus_one"
        @n_plus_one_patterns = detector.aggregate_patterns(limit: 20)
        @affected_traces = detector.find_affected_traces(limit: 10)
      when "slow"
        @slow_queries = analyzer.slow_queries(threshold_ms: @threshold, limit: 50)
      when "frequent"
        @frequent_queries = analyzer.frequent_queries(limit: 30)
        @table_breakdown = analyzer.table_breakdown
      end
    end

    def show
      @trace = current_project.traces.find_by!(trace_id: params[:id])
      @since = parse_since(params[:since])

      detector = NPlusOneDetector.new(project: current_project, since: @since)
      @patterns = detector.analyze_trace(@trace)

      @total_repeated = @patterns.sum { |p| p[:count] }
      @potential_savings = @patterns.sum { |p| p[:total_duration_ms] * (1 - 1.0 / p[:count]) }
    end

    private

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
