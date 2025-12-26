class TraceProcessor
  def initialize(project:, payload:)
    @project = project
    @payload = payload.deep_symbolize_keys
  end

  def process!
    trace = find_or_create_trace

    # Batch insert spans if included
    if @payload[:spans].present?
      create_spans_batch(trace, @payload[:spans])
    end

    # Complete trace if ended_at is provided
    if @payload[:ended_at]
      trace.complete!(
        ended_at: parse_timestamp(@payload[:ended_at]),
        error: @payload[:error] || false,
        error_class: @payload[:error_class],
        error_message: @payload[:error_message]
      )
    end

    # Broadcast for real-time dashboard
    broadcast_trace(trace)

    # Update aggregated metrics
    update_aggregates(trace) if trace.ended_at.present?

    trace
  end

  private

  def find_or_create_trace
    # Use find_by + create! to avoid issues with TimescaleDB composite primary keys
    # (find_or_create_by! fails with "No unique index found for id")
    trace = @project.traces.find_by(trace_id: @payload[:trace_id])
    return trace if trace

    @project.traces.create!(
      trace_id: @payload[:trace_id],
      name: @payload[:name] || build_name,
      kind: @payload[:kind] || 'request',
      started_at: parse_timestamp(@payload[:started_at]) || Time.current,
      request_id: @payload[:request_id],
      request_method: @payload[:request_method],
      request_path: @payload[:request_path],
      controller: @payload[:controller],
      action: @payload[:action],
      status: @payload[:status],
      view_duration_ms: @payload[:view_ms] || 0.0,
      db_duration_ms: @payload[:db_ms] || 0.0,
      external_duration_ms: @payload[:external_ms] || 0.0,
      job_class: @payload[:job_class],
      job_id: @payload[:job_id],
      queue: @payload[:queue],
      queue_wait_ms: @payload[:queue_wait_ms],
      executions: @payload[:executions] || 1,
      environment: @payload[:environment],
      commit: @payload[:commit],
      host: @payload[:host],
      user_id: @payload[:user_id]
    )
  end

  def create_spans_batch(trace, spans_data)
    return if spans_data.empty?

    now = Time.current
    records = spans_data.map do |span_data|
      # Convert data to JSON for JSONB column
      data = span_data[:data]
      data = data.to_unsafe_h if data.respond_to?(:to_unsafe_h)
      data = (data || {}).to_json

      {
        id: SecureRandom.uuid,
        trace_id: trace.id,
        project_id: @project.id,
        span_id: span_data[:span_id] || SecureRandom.hex(8),
        parent_span_id: span_data[:parent_span_id],
        name: span_data[:name],
        kind: span_data[:kind] || 'custom',
        started_at: parse_timestamp(span_data[:started_at]) || now,
        ended_at: parse_timestamp(span_data[:ended_at]),
        duration_ms: span_data[:duration_ms],
        data: data,
        error: span_data[:error] || false,
        error_class: span_data[:error_class],
        error_message: span_data[:error_message]
      }
    end

    # Use raw SQL for bulk inserts to avoid Rails 8.1 unique index validation
    # which fails for TimescaleDB hypertables with composite primary keys
    bulk_insert_spans(records)
  end

  def bulk_insert_spans(records)
    return if records.empty?

    columns = records.first.keys
    values = records.map do |record|
      columns.map { |col| ActiveRecord::Base.connection.quote(record[col]) }.join(", ")
    end

    sql = <<~SQL
      INSERT INTO spans (#{columns.join(', ')})
      VALUES #{values.map { |v| "(#{v})" }.join(', ')}
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end

  def build_name
    if @payload[:request_method] && @payload[:request_path]
      "#{@payload[:request_method]} #{normalize_path(@payload[:request_path])}"
    elsif @payload[:job_class]
      @payload[:job_class]
    else
      'Unknown'
    end
  end

  def normalize_path(path)
    # Replace IDs with :id for grouping
    path.gsub(/\/\d+/, '/:id').gsub(/\/[a-f0-9-]{36}/, '/:uuid')
  end

  def parse_timestamp(ts)
    case ts
    when Time, DateTime then ts
    when String then Time.parse(ts)
    when Numeric then Time.at(ts)
    else nil
    end
  rescue
    nil
  end

  def broadcast_trace(trace)
    # ActionCable broadcast for real-time updates
    ActionCable.server.broadcast(
      "metrics_#{@project.id}",
      {
        type: 'trace',
        trace: {
          id: trace.id,
          name: trace.name,
          duration_ms: trace.duration_ms,
          status: trace.status,
          error: trace.error
        }
      }
    )
  rescue => e
    Rails.logger.warn("[TraceProcessor] Broadcast failed: #{e.message}")
  end

  def update_aggregates(trace)
    AggregateMetricsJob.perform_later(trace.id)
  rescue => e
    Rails.logger.warn("[TraceProcessor] Aggregate job failed: #{e.message}")
  end
end
