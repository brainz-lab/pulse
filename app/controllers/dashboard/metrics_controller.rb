module Dashboard
  class MetricsController < BaseController
    def index
      @metrics = current_project.metrics
    end

    def show
      @metric = current_project.metrics.find(params[:id])
      @since = parse_since(params[:since])
      @stats = @metric.stats(since: @since)
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
