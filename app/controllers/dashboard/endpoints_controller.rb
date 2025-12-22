module Dashboard
  class EndpointsController < BaseController
    def index
      @since = parse_since(params[:since])

      @endpoints = current_project.traces
        .requests
        .where('started_at >= ?', @since)
        .where.not(duration_ms: nil)
        .group(:name)
        .select(
          'name',
          'COUNT(*) as count',
          'AVG(duration_ms) as avg_duration',
          'MAX(duration_ms) as max_duration',
          'SUM(CASE WHEN error THEN 1 ELSE 0 END) as error_count'
        )
        .order('count DESC')
        .limit(50)
    end

    def show
      @since = parse_since(params[:since])
      @endpoint_name = params[:id]

      traces_scope = current_project.traces
        .requests
        .where(name: @endpoint_name)
        .where('started_at >= ?', @since)

      @stats = traces_scope
        .where.not(duration_ms: nil)
        .select(
          'COUNT(*) as count',
          'AVG(duration_ms) as avg_duration',
          'MAX(duration_ms) as max_duration',
          'MIN(duration_ms) as min_duration',
          'PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration',
          'SUM(CASE WHEN error THEN 1 ELSE 0 END) as error_count'
        ).reorder(nil).take

      @rpm_data = traces_scope
        .group("date_trunc('minute', started_at)")
        .count
        .sort
        .map { |time, count| { x: time.iso8601, y: count } }

      @response_time_data = traces_scope
        .where.not(duration_ms: nil)
        .group("date_trunc('minute', started_at)")
        .average(:duration_ms)
        .sort
        .map { |time, avg| { x: time.iso8601, y: avg&.round(2) } }

      @recent_requests = traces_scope.order(started_at: :desc).limit(10)
    end

    private

    def parse_since(value)
      case value
      when '6h' then 6.hours.ago
      when '24h' then 24.hours.ago
      when '7d' then 7.days.ago
      else 1.hour.ago
      end
    end
  end
end
