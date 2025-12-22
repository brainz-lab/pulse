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
