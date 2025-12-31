module Dashboard
  class OverviewController < BaseController
    def show
      @since = parse_since(params[:since])
      @overview = current_project.overview(since: @since)

      @throughput_data = throughput_data
      @response_time_data = response_time_data
      @slow_requests = current_project.traces.requests.slow(500).recent.limit(5)
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

    def throughput_data
      current_project.traces
        .requests
        .where("started_at >= ?", @since)
        .group("date_trunc('minute', started_at)")
        .count
        .sort
        .map { |time, count| { x: time.iso8601, y: count } }
    end

    def response_time_data
      current_project.traces
        .requests
        .where("started_at >= ?", @since)
        .where.not(duration_ms: nil)
        .group("date_trunc('minute', started_at)")
        .average(:duration_ms)
        .sort
        .map { |time, avg| { x: time.iso8601, y: avg&.round(2) } }
    end
  end
end
