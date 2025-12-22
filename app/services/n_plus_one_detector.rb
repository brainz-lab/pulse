class NPlusOneDetector
  MINIMUM_REPEAT_COUNT = 3 # Minimum repeated queries to flag as N+1

  def initialize(project:, since: 1.hour.ago)
    @project = project
    @since = since
  end

  # Analyze a single trace for N+1 patterns
  def analyze_trace(trace)
    db_spans = trace.spans.db_spans.order(:started_at)
    return [] if db_spans.count < MINIMUM_REPEAT_COUNT

    # Group by normalized SQL pattern
    query_groups = db_spans.group_by do |span|
      SqlNormalizer.normalize(span.data['sql'])
    end.compact

    patterns = []

    query_groups.each do |normalized_sql, spans|
      next if normalized_sql.blank?
      next if spans.count < MINIMUM_REPEAT_COUNT

      total_duration = spans.sum { |s| s.duration_ms.to_f }

      patterns << {
        normalized_sql: normalized_sql,
        fingerprint: SqlNormalizer.fingerprint(normalized_sql),
        count: spans.count,
        total_duration_ms: total_duration,
        avg_duration_ms: (total_duration / spans.count).round(2),
        table: spans.first.data['table'],
        operation: spans.first.data['operation'],
        example_sql: spans.first.data['sql'],
        span_ids: spans.map(&:span_id)
      }
    end

    patterns.sort_by { |p| -p[:count] }
  end

  # Find all traces with N+1 patterns in the time range
  def find_affected_traces(limit: 50)
    traces = @project.traces
      .where('started_at >= ?', @since)
      .where('span_count >= ?', MINIMUM_REPEAT_COUNT)
      .includes(:spans)
      .order(started_at: :desc)
      .limit(limit * 2) # Fetch more to filter

    affected = []

    traces.each do |trace|
      patterns = analyze_trace(trace)
      next if patterns.empty?

      total_repeated = patterns.sum { |p| p[:count] }
      potential_savings = patterns.sum { |p| p[:total_duration_ms] * (1 - 1.0 / p[:count]) }

      affected << {
        trace: trace,
        patterns: patterns,
        total_repeated_queries: total_repeated,
        potential_savings_ms: potential_savings
      }

      break if affected.size >= limit
    end

    affected.sort_by { |a| -a[:potential_savings_ms] }
  end

  # Aggregate N+1 patterns across all traces
  def aggregate_patterns(limit: 20)
    pattern_stats = Hash.new do |h, k|
      h[k] = {
        count: 0,
        trace_count: 0,
        total_duration_ms: 0,
        normalized_sql: nil,
        example_sql: nil,
        table: nil,
        operation: nil,
        trace_ids: Set.new
      }
    end

    @project.traces
      .where('started_at >= ?', @since)
      .where('span_count >= ?', MINIMUM_REPEAT_COUNT)
      .includes(:spans)
      .find_each do |trace|

      patterns = analyze_trace(trace)

      patterns.each do |pattern|
        fingerprint = pattern[:fingerprint]
        stats = pattern_stats[fingerprint]

        stats[:count] += pattern[:count]
        stats[:trace_count] += 1
        stats[:total_duration_ms] += pattern[:total_duration_ms]
        stats[:normalized_sql] ||= pattern[:normalized_sql]
        stats[:example_sql] ||= pattern[:example_sql]
        stats[:table] ||= pattern[:table]
        stats[:operation] ||= pattern[:operation]
        stats[:trace_ids] << trace.id
      end
    end

    pattern_stats.map do |fingerprint, stats|
      stats.merge(
        fingerprint: fingerprint,
        trace_ids: stats[:trace_ids].to_a.first(5)
      )
    end.sort_by { |p| -p[:count] }.first(limit)
  end
end
