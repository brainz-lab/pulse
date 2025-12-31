class QueryAnalyzer
  def initialize(project:, since: 1.hour.ago)
    @project = project
    @since = since
  end

  # Find the slowest individual queries
  def slow_queries(threshold_ms: 100, limit: 50)
    db_spans = Span.joins(:trace)
      .where(traces: { project_id: @project.id })
      .where("traces.started_at >= ?", @since)
      .db_spans
      .where("spans.duration_ms >= ?", threshold_ms)
      .order("spans.duration_ms DESC")
      .limit(limit)

    db_spans.map do |span|
      {
        span_id: span.span_id,
        trace_id: span.trace.trace_id,
        sql: span.data["sql"],
        normalized_sql: SqlNormalizer.normalize(span.data["sql"]),
        table: span.data["table"],
        operation: span.data["operation"],
        duration_ms: span.duration_ms,
        started_at: span.started_at,
        trace_name: span.trace.name
      }
    end
  end

  # Find most frequently executed query patterns
  def frequent_queries(limit: 20)
    db_spans = Span.joins(:trace)
      .where(traces: { project_id: @project.id })
      .where("traces.started_at >= ?", @since)
      .db_spans

    # Group by fingerprint in memory (more flexible than SQL grouping for JSONB)
    pattern_stats = Hash.new do |h, k|
      h[k] = {
        count: 0,
        total_duration_ms: 0,
        normalized_sql: nil,
        example_sql: nil,
        table: nil,
        operation: nil
      }
    end

    db_spans.find_each do |span|
      sql = span.data["sql"]
      next if sql.blank?

      fingerprint = SqlNormalizer.fingerprint(sql)
      next if fingerprint.nil?

      stats = pattern_stats[fingerprint]
      stats[:count] += 1
      stats[:total_duration_ms] += span.duration_ms.to_f
      stats[:normalized_sql] ||= SqlNormalizer.normalize(sql)
      stats[:example_sql] ||= sql
      stats[:table] ||= span.data["table"]
      stats[:operation] ||= span.data["operation"]
    end

    pattern_stats.map do |fingerprint, stats|
      stats.merge(
        fingerprint: fingerprint,
        avg_duration_ms: stats[:count] > 0 ? (stats[:total_duration_ms] / stats[:count]).round(2) : 0
      )
    end.sort_by { |p| -p[:count] }.first(limit)
  end

  # Get summary statistics
  def summary
    traces = @project.traces.where("started_at >= ?", @since)

    db_spans = Span.joins(:trace)
      .where(traces: { project_id: @project.id })
      .where("traces.started_at >= ?", @since)
      .db_spans

    total_queries = db_spans.count
    return empty_summary if total_queries == 0

    durations = db_spans.pluck("spans.duration_ms").compact
    avg_duration = durations.any? ? (durations.sum / durations.size).round(2) : 0

    slow_count = db_spans.where("spans.duration_ms >= ?", 100).count
    very_slow_count = db_spans.where("spans.duration_ms >= ?", 500).count

    tables = db_spans.pluck(Arel.sql("spans.data->>'table'")).compact.uniq.reject(&:blank?)

    {
      total_queries: total_queries,
      avg_duration_ms: avg_duration,
      slow_count: slow_count,
      very_slow_count: very_slow_count,
      tables: tables,
      table_count: tables.size,
      trace_count: traces.count,
      queries_per_trace: traces.count > 0 ? (total_queries.to_f / traces.count).round(1) : 0
    }
  end

  # Get query distribution by table
  def table_breakdown
    db_spans = Span.joins(:trace)
      .where(traces: { project_id: @project.id })
      .where("traces.started_at >= ?", @since)
      .db_spans

    table_stats = Hash.new do |h, k|
      h[k] = { count: 0, total_duration_ms: 0 }
    end

    db_spans.find_each do |span|
      table = span.data["table"]
      next if table.blank?

      table_stats[table][:count] += 1
      table_stats[table][:total_duration_ms] += span.duration_ms.to_f
    end

    table_stats.map do |table, stats|
      {
        table: table,
        count: stats[:count],
        total_duration_ms: stats[:total_duration_ms].round(2),
        avg_duration_ms: stats[:count] > 0 ? (stats[:total_duration_ms] / stats[:count]).round(2) : 0
      }
    end.sort_by { |t| -t[:count] }
  end

  private

  def empty_summary
    {
      total_queries: 0,
      avg_duration_ms: 0,
      slow_count: 0,
      very_slow_count: 0,
      tables: [],
      table_count: 0,
      trace_count: 0,
      queries_per_trace: 0
    }
  end
end
