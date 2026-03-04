module Dashboard
  class OverviewController < BaseController
    def show
      @since = parse_since(params[:since])
      @overview = current_project.overview(since: @since)

      @throughput_data = throughput_data
      @response_time_data = response_time_data
      @slow_requests = current_project.traces.requests.slow(500)
        .where("started_at >= ?", @since).order(duration_ms: :desc).limit(5)

      # Comparison: previous equivalent period
      range_duration = Time.current - @since
      @comparison = current_project.overview(since: @since - range_duration)
      @deltas = compute_deltas(@overview, @comparison)

      # Heatmap data
      @heatmap_data = heatmap_data
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

    def compute_deltas(current, previous)
      {}.tap do |d|
        [ :apdex, :rpm, :avg_duration, :p95_duration, :error_rate ].each do |metric|
          curr = current[metric].to_f
          prev = previous[metric].to_f
          d[metric] = prev > 0 ? ((curr - prev) / prev * 100).round(1) : 0
        end
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

    def heatmap_data
      buckets = [ 0, 50, 100, 200, 500, 1000, 2000, 5000 ]
      bucket_selects = buckets.each_cons(2).map { |low, high|
        "COUNT(*) FILTER (WHERE duration_ms >= #{low} AND duration_ms < #{high}) as bucket_#{low}_#{high}"
      }
      bucket_selects << "COUNT(*) FILTER (WHERE duration_ms >= 5000) as bucket_5000_plus"

      data = current_project.traces.requests
        .where("started_at >= ?", @since)
        .where.not(duration_ms: nil)
        .group("date_trunc('minute', started_at)")
        .select(
          "date_trunc('minute', started_at) as bucket_time",
          *bucket_selects
        )
        .order("bucket_time")

      data.map { |row| row.attributes.except("id") }
    end
  end
end
