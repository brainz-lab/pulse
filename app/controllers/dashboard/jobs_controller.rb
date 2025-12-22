module Dashboard
  class JobsController < BaseController
    def index
      @since = parse_since(params[:since])
      @jobs = current_project.traces.jobs.where('started_at >= ?', @since).recent.limit(100)

      @job_stats = current_project.traces.jobs
        .where('started_at >= ?', @since)
        .group(:name)
        .select(
          'name',
          'COUNT(*) as count',
          'AVG(duration_ms) as avg_duration',
          'MAX(duration_ms) as max_duration',
          'SUM(CASE WHEN error THEN 1 ELSE 0 END) as error_count'
        )
        .order('count DESC')
        .limit(20)
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
