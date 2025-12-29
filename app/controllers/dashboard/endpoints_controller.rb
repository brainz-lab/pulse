require 'ostruct'

module Dashboard
  class EndpointsController < BaseController
    def index
      @since = parse_since(params[:since])
      @search = params[:search]
      @group_by = params[:group_by] || 'endpoint' # 'endpoint' or 'prefix'
      @method_filter = params[:method]
      @sort = params[:sort] || 'count'
      @sort_dir = params[:sort_dir] || 'desc'

      if @group_by == 'prefix'
        @endpoints = fetch_endpoint_groups
      else
        @endpoints = fetch_endpoints.to_a
      end

      # Get path prefix groups for sidebar navigation
      @path_prefixes = current_project.traces
        .requests
        .where('started_at >= ?', @since)
        .where.not(name: nil)
        .pluck(:name)
        .map { |n| extract_path_prefix(n) }
        .compact
        .tally
        .sort_by { |_, count| -count }
        .first(10)
    end

    private

    def fetch_endpoints
      scope = current_project.traces
        .requests
        .where('started_at >= ?', @since)
        .where.not(duration_ms: nil)

      # Apply search filter
      if @search.present?
        scope = scope.where('name ILIKE ?', "%#{@search}%")
      end

      # Apply method filter
      if @method_filter.present?
        scope = scope.where(request_method: @method_filter)
      end

      # Build query with P95/P99
      sort_column = case @sort
                    when 'avg' then 'avg_duration'
                    when 'p95' then 'p95_duration'
                    when 'errors' then 'error_rate'
                    else 'count'
                    end
      sort_order = @sort_dir == 'asc' ? 'ASC' : 'DESC'

      scope.group(:name)
        .select(
          'name',
          'COUNT(*) as count',
          'AVG(duration_ms) as avg_duration',
          'MAX(duration_ms) as max_duration',
          'PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration',
          'PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99_duration',
          'SUM(CASE WHEN error THEN 1 ELSE 0 END) as error_count',
          '(SUM(CASE WHEN error THEN 1 ELSE 0 END)::float / COUNT(*) * 100) as error_rate'
        )
        .order("#{sort_column} #{sort_order}")
        .limit(100)
    end

    def fetch_endpoint_groups
      traces = current_project.traces
        .requests
        .where('started_at >= ?', @since)
        .where.not(duration_ms: nil)
        .where.not(name: nil)

      # Group by path prefix
      grouped = traces.pluck(:name, :duration_ms, :error).group_by do |name, _, _|
        extract_path_prefix(name)
      end

      grouped.map do |prefix, records|
        next if prefix.nil?

        durations = records.map { |r| r[1] }.compact.sort
        error_count = records.count { |r| r[2] }
        total = records.count

        OpenStruct.new(
          name: "#{prefix}/*",
          prefix: prefix,
          count: total,
          avg_duration: durations.any? ? (durations.sum.to_f / durations.length) : 0,
          max_duration: durations.max || 0,
          p95_duration: percentile(durations, 0.95),
          p99_duration: percentile(durations, 0.99),
          error_count: error_count,
          error_rate: total > 0 ? (error_count.to_f / total * 100) : 0,
          endpoint_count: records.map { |r| r[0] }.uniq.count
        )
      end.compact.sort_by { |e| -e.count }.first(50)
    end

    def extract_path_prefix(endpoint_name)
      return nil if endpoint_name.blank?

      parts = endpoint_name.split(' ', 2)
      path = parts.length > 1 ? parts[1] : endpoint_name

      segments = path.split('/').reject(&:blank?)
      return nil if segments.length < 2

      "/" + segments[0..1].join('/')
    end

    def percentile(sorted_values, p)
      return nil if sorted_values.empty?
      index = (sorted_values.length * p).ceil - 1
      sorted_values[[index, 0].max]
    end

    public

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
