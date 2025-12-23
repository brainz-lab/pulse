class TraceProcessor
  def initialize(project:, payload:)
    @project = project
    @payload = payload.deep_symbolize_keys
  end

  def process!
    trace = find_or_create_trace

    # Process spans if included
    if @payload[:spans].present?
      @payload[:spans].each do |span_data|
        create_span(trace, span_data)
      end
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
    @project.traces.find_or_create_by!(trace_id: @payload[:trace_id]) do |t|
      t.name = @payload[:name] || build_name
      t.kind = @payload[:kind] || 'request'
      t.started_at = parse_timestamp(@payload[:started_at]) || Time.current

      t.request_id = @payload[:request_id]
      t.request_method = @payload[:request_method]
      t.request_path = @payload[:request_path]
      t.controller = @payload[:controller]
      t.action = @payload[:action]
      t.status = @payload[:status]

      # Timing breakdown
      t.view_duration_ms = @payload[:view_ms] || 0.0
      t.db_duration_ms = @payload[:db_ms] || 0.0
      t.external_duration_ms = @payload[:external_ms] || 0.0

      t.job_class = @payload[:job_class]
      t.job_id = @payload[:job_id]
      t.queue = @payload[:queue]
      t.queue_wait_ms = @payload[:queue_wait_ms]
      t.executions = @payload[:executions] || 1

      t.environment = @payload[:environment]
      t.commit = @payload[:commit]
      t.host = @payload[:host]
      t.user_id = @payload[:user_id]
    end
  end

  def create_span(trace, span_data)
    trace.spans.create!(
      project: @project,
      span_id: span_data[:span_id] || SecureRandom.hex(8),
      parent_span_id: span_data[:parent_span_id],
      name: span_data[:name],
      kind: span_data[:kind] || 'custom',
      started_at: parse_timestamp(span_data[:started_at]) || Time.current,
      ended_at: parse_timestamp(span_data[:ended_at]),
      duration_ms: span_data[:duration_ms],
      data: span_data[:data] || {},
      error: span_data[:error] || false,
      error_class: span_data[:error_class],
      error_message: span_data[:error_message]
    )
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
