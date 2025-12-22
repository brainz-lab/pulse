class MetricsAggregator
  def initialize(project:)
    @project = project
  end

  def aggregate_minute!(timestamp)
    bucket = timestamp.beginning_of_minute

    traces = @project.traces
      .where(started_at: bucket...bucket + 1.minute)
      .where(kind: 'request')
      .where.not(duration_ms: nil)

    return if traces.empty?

    durations = traces.pluck(:duration_ms).sort

    create_or_update_aggregate(
      name: 'request_duration',
      bucket: bucket,
      granularity: 'minute',
      values: durations
    )

    create_or_update_aggregate(
      name: 'throughput',
      bucket: bucket,
      granularity: 'minute',
      values: [traces.count]
    )

    error_count = traces.where(error: true).count
    create_or_update_aggregate(
      name: 'error_rate',
      bucket: bucket,
      granularity: 'minute',
      values: [(error_count.to_f / traces.count * 100).round(2)]
    )
  end

  private

  def create_or_update_aggregate(name:, bucket:, granularity:, values:, dimensions: {})
    sorted = values.sort

    AggregatedMetric.upsert({
      project_id: @project.id,
      name: name,
      bucket: bucket,
      granularity: granularity,
      count: values.count,
      sum: values.sum,
      min: sorted.first,
      max: sorted.last,
      avg: (values.sum.to_f / values.count).round(2),
      p50: percentile(sorted, 0.50),
      p95: percentile(sorted, 0.95),
      p99: percentile(sorted, 0.99),
      dimensions: dimensions
    }, unique_by: [:project_id, :name, :bucket, :granularity])
  end

  def percentile(sorted_values, p)
    return nil if sorted_values.empty?
    index = (sorted_values.length * p).ceil - 1
    sorted_values[[index, 0].max]
  end
end
