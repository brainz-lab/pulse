class MetricsAggregator
  def initialize(project:)
    @project = project
  end

  def aggregate_minute!(timestamp)
    bucket = timestamp.beginning_of_minute

    aggregate_requests!(bucket)
    aggregate_endpoints!(bucket)
    aggregate_external_http!(bucket)
    aggregate_cache!(bucket)
    aggregate_jobs!(bucket)
  end

  private

  def aggregate_requests!(bucket)
    traces = @project.traces
      .where(started_at: bucket...bucket + 1.minute)
      .where(kind: "request")
      .where.not(duration_ms: nil)

    return if traces.empty?

    durations = traces.pluck(:duration_ms).sort

    create_or_update_aggregate(
      name: "request_duration",
      bucket: bucket,
      granularity: "minute",
      values: durations
    )

    create_or_update_aggregate(
      name: "throughput",
      bucket: bucket,
      granularity: "minute",
      values: [ traces.count ]
    )

    error_count = traces.where(error: true).count
    create_or_update_aggregate(
      name: "error_rate",
      bucket: bucket,
      granularity: "minute",
      values: [ (error_count.to_f / traces.count * 100).round(2) ]
    )
  end

  def aggregate_endpoints!(bucket)
    traces = @project.traces
      .where(started_at: bucket...bucket + 1.minute)
      .where(kind: "request")
      .where.not(duration_ms: nil)
      .where.not(name: nil)

    return if traces.empty?

    # Group by endpoint name
    traces.group(:name).pluck(:name).each do |endpoint_name|
      endpoint_traces = traces.where(name: endpoint_name)
      durations = endpoint_traces.pluck(:duration_ms).sort

      next if durations.empty?

      error_count = endpoint_traces.where(error: true).count

      # Endpoint duration metrics
      create_or_update_aggregate(
        name: "endpoint_duration",
        bucket: bucket,
        granularity: "minute",
        values: durations,
        dimensions: { endpoint: endpoint_name }
      )

      # Endpoint throughput
      create_or_update_aggregate(
        name: "endpoint_throughput",
        bucket: bucket,
        granularity: "minute",
        values: [ endpoint_traces.count ],
        dimensions: { endpoint: endpoint_name }
      )

      # Endpoint error rate
      create_or_update_aggregate(
        name: "endpoint_error_rate",
        bucket: bucket,
        granularity: "minute",
        values: [ (error_count.to_f / endpoint_traces.count * 100).round(2) ],
        dimensions: { endpoint: endpoint_name }
      )

      # Also aggregate by HTTP method if available
      endpoint_traces.where.not(request_method: nil).group(:request_method).pluck(:request_method).each do |method|
        method_traces = endpoint_traces.where(request_method: method)
        method_durations = method_traces.pluck(:duration_ms).sort

        next if method_durations.empty?

        create_or_update_aggregate(
          name: "endpoint_duration",
          bucket: bucket,
          granularity: "minute",
          values: method_durations,
          dimensions: { endpoint: endpoint_name, method: method }
        )
      end

      # Aggregate by path prefix for hierarchy (e.g., /api/v1/*)
      path_prefix = extract_path_prefix(endpoint_name)
      if path_prefix
        create_or_update_aggregate(
          name: "endpoint_group_throughput",
          bucket: bucket,
          granularity: "minute",
          values: [ endpoint_traces.count ],
          dimensions: { prefix: path_prefix }
        )
      end
    end
  end

  # Extract path prefix for hierarchical grouping (e.g., "POST /api/v1/users" -> "/api/v1")
  def extract_path_prefix(endpoint_name)
    return nil if endpoint_name.blank?

    # Extract path from endpoint name (e.g., "POST /api/v1/users" -> "/api/v1/users")
    parts = endpoint_name.split(" ", 2)
    path = parts.length > 1 ? parts[1] : endpoint_name

    # Extract first two path segments (e.g., "/api/v1")
    segments = path.split("/").reject(&:blank?)
    return nil if segments.length < 2

    "/" + segments[0..1].join("/")
  end

  def aggregate_external_http!(bucket)
    # Get all HTTP spans from traces in this minute
    spans = @project.spans
      .joins(:trace)
      .where(traces: { started_at: bucket...bucket + 1.minute })
      .where(kind: "http")

    return if spans.empty?

    # Group by host (extracted from span data)
    spans_by_host = spans.group_by { |s| s.data&.dig("host") || "unknown" }

    spans_by_host.each do |host, host_spans|
      next if host == "unknown"

      durations = host_spans.map(&:duration_ms).compact.sort
      next if durations.empty?

      error_count = host_spans.count { |s| s.error }

      create_or_update_aggregate(
        name: "external_http_duration",
        bucket: bucket,
        granularity: "minute",
        values: durations,
        dimensions: { host: host }
      )

      create_or_update_aggregate(
        name: "external_http_count",
        bucket: bucket,
        granularity: "minute",
        values: [ host_spans.count ],
        dimensions: { host: host }
      )

      create_or_update_aggregate(
        name: "external_http_error_rate",
        bucket: bucket,
        granularity: "minute",
        values: [ (error_count.to_f / host_spans.count * 100).round(2) ],
        dimensions: { host: host }
      )
    end
  end

  def aggregate_cache!(bucket)
    # Get all cache spans from traces in this minute
    spans = @project.spans
      .joins(:trace)
      .where(traces: { started_at: bucket...bucket + 1.minute })
      .where(kind: "cache")

    return if spans.empty?

    # Calculate hit rate
    reads = spans.select { |s| s.data&.dig("operation") == "read" }
    hits = reads.select { |s| s.data&.dig("hit") == true }
    misses = reads.select { |s| s.data&.dig("hit") == false }

    if reads.any?
      hit_rate = (hits.count.to_f / reads.count * 100).round(2)
      create_or_update_aggregate(
        name: "cache_hit_rate",
        bucket: bucket,
        granularity: "minute",
        values: [ hit_rate ]
      )

      create_or_update_aggregate(
        name: "cache_hits",
        bucket: bucket,
        granularity: "minute",
        values: [ hits.count ]
      )

      create_or_update_aggregate(
        name: "cache_misses",
        bucket: bucket,
        granularity: "minute",
        values: [ misses.count ]
      )
    end

    # Cache operation durations
    durations = spans.map(&:duration_ms).compact.sort
    if durations.any?
      create_or_update_aggregate(
        name: "cache_duration",
        bucket: bucket,
        granularity: "minute",
        values: durations
      )
    end
  end

  def aggregate_jobs!(bucket)
    traces = @project.traces
      .where(started_at: bucket...bucket + 1.minute)
      .where(kind: "job")
      .where.not(duration_ms: nil)

    return if traces.empty?

    durations = traces.pluck(:duration_ms).sort

    create_or_update_aggregate(
      name: "job_duration",
      bucket: bucket,
      granularity: "minute",
      values: durations
    )

    create_or_update_aggregate(
      name: "job_count",
      bucket: bucket,
      granularity: "minute",
      values: [ traces.count ]
    )

    error_count = traces.where(error: true).count
    create_or_update_aggregate(
      name: "job_error_rate",
      bucket: bucket,
      granularity: "minute",
      values: [ (error_count.to_f / traces.count * 100).round(2) ]
    )

    # Queue wait time aggregation
    wait_times = traces.where.not(queue_wait_ms: nil).pluck(:queue_wait_ms).sort
    if wait_times.any?
      create_or_update_aggregate(
        name: "job_queue_wait",
        bucket: bucket,
        granularity: "minute",
        values: wait_times
      )
    end

    # Aggregate by queue
    traces.pluck(:queue).uniq.compact.each do |queue|
      queue_traces = traces.where(queue: queue)
      queue_durations = queue_traces.pluck(:duration_ms).sort

      create_or_update_aggregate(
        name: "job_duration",
        bucket: bucket,
        granularity: "minute",
        values: queue_durations,
        dimensions: { queue: queue }
      )

      create_or_update_aggregate(
        name: "job_count",
        bucket: bucket,
        granularity: "minute",
        values: [ queue_traces.count ],
        dimensions: { queue: queue }
      )
    end
  end

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
    }, unique_by: [ :project_id, :name, :bucket, :granularity ])
  end

  def percentile(sorted_values, p)
    return nil if sorted_values.empty?
    index = (sorted_values.length * p).ceil - 1
    sorted_values[[ index, 0 ].max]
  end
end
