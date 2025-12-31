class TraceProcessor
  def initialize(project:, payload:, preloaded_traces: nil)
    @project = project
    @payload = payload.deep_symbolize_keys
    @preloaded_traces = preloaded_traces
  end

  # Process a batch of traces efficiently to avoid N+1 queries
  # Returns array of processed traces
  def self.process_batch!(project:, payloads:)
    return [] if payloads.empty?

    payloads = payloads.map(&:deep_symbolize_keys)
    trace_ids = payloads.map { |p| p[:trace_id] }.compact

    # Pre-fetch all existing traces in one query to avoid N+1
    existing_traces = project.traces.where(trace_id: trace_ids).index_by(&:trace_id)

    results = []
    completions = []
    new_trace_records = []
    spans_to_create = []

    # Wrap all operations in a single transaction to avoid N+1 TRANSACTION
    ActiveRecord::Base.transaction do
      # First pass: collect new traces and identify existing ones
      payloads.each do |payload|
        existing = existing_traces[payload[:trace_id]]
        if existing
          results << existing
        else
          processor = new(project: project, payload: payload, preloaded_traces: existing_traces)
          new_trace_records << processor.send(:build_trace_record)
          # Collect spans for this trace (will be linked after bulk insert)
          if payload[:spans].present?
            spans_to_create << { payload: payload, index: new_trace_records.size - 1 }
          end
        end
      end

      # Bulk insert all new traces at once to avoid N+1 INSERT
      if new_trace_records.any?
        # Use raw SQL bulk insert to avoid TimescaleDB unique index issues
        bulk_insert_traces(new_trace_records)

        # Fetch the inserted traces to get full objects
        inserted_trace_ids = new_trace_records.map { |r| r[:trace_id] }
        inserted_traces = project.traces.where(trace_id: inserted_trace_ids).index_by(&:trace_id)

        # Add inserted traces to results and create spans
        new_trace_records.each_with_index do |record, idx|
          trace = inserted_traces[record[:trace_id]]
          results << trace

          # Find if this trace has spans to create
          span_info = spans_to_create.find { |s| s[:index] == idx }
          if span_info
            processor = new(project: project, payload: span_info[:payload], preloaded_traces: existing_traces)
            processor.send(:create_spans_batch, trace, span_info[:payload][:spans])
          end
        end
      end

      # Sort results to match original payload order
      results = payloads.map { |p| results.find { |t| t.trace_id == p[:trace_id] } }.compact

      # Collect completion data for traces with ended_at
      payloads.each_with_index do |payload, idx|
        next unless payload[:ended_at]
        trace = results.find { |t| t.trace_id == payload[:trace_id] }
        next unless trace

        processor = new(project: project, payload: payload, preloaded_traces: existing_traces)
        completions << {
          trace: trace,
          ended_at: processor.send(:parse_timestamp, payload[:ended_at]),
          error: payload[:error] || false,
          error_class: payload[:error_class],
          error_message: payload[:error_message]
        }
      end

      # Batch complete all traces using single bulk UPDATE
      Trace.complete_batch!(completions) if completions.any?
    end

    # Batch broadcast after all processing (outside transaction for performance)
    results.each { |trace| new(project: project, payload: {}).send(:broadcast_trace, trace) }

    # Batch enqueue aggregate jobs (outside transaction to avoid blocking)
    completions.each do |completion|
      AggregateMetricsJob.perform_later(completion[:trace].id)
    end

    results
  end

  # Bulk insert traces using raw SQL to avoid TimescaleDB unique index issues
  def self.bulk_insert_traces(records)
    return if records.empty?

    columns = records.first.keys
    values = records.map do |record|
      columns.map { |col| ActiveRecord::Base.connection.quote(record[col]) }.join(", ")
    end

    sql = <<~SQL
      INSERT INTO traces (#{columns.join(', ')})
      VALUES #{values.map { |v| "(#{v})" }.join(', ')}
    SQL

    ActiveRecord::Base.connection.execute(sql)
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

    # Broadcast for real-time dashboard (skip if called from batch)
    broadcast_trace(trace) unless @preloaded_traces

    # Update aggregated metrics (skip if called from batch)
    update_aggregates(trace) if trace.ended_at.present? && !@preloaded_traces

    trace
  end

  # Process trace without completing - used for batch processing
  # Completion is handled separately in batch to avoid N+1 transactions
  def process_without_completion!
    trace = find_or_create_trace

    # Batch insert spans if included
    if @payload[:spans].present?
      create_spans_batch(trace, @payload[:spans])
    end

    trace
  end

  private

  def find_or_create_trace
    # Use preloaded traces if available (batch processing)
    if @preloaded_traces
      trace = @preloaded_traces[@payload[:trace_id]]
      return trace if trace

      # We already checked all existing traces, so skip uniqueness validation
      # This avoids N+1 "Trace Exists?" queries during batch processing
      return create_trace!(skip_uniqueness: true)
    else
      # Single trace processing - use find_by + create! to avoid issues with TimescaleDB composite primary keys
      # (find_or_create_by! fails with "No unique index found for id")
      trace = @project.traces.find_by(trace_id: @payload[:trace_id])
      return trace if trace
    end

    create_trace!(skip_uniqueness: false)
  end

  # Build a hash for bulk insert (used by process_batch!)
  def build_trace_record
    now = Time.current
    {
      id: SecureRandom.uuid,
      project_id: @project.id,
      trace_id: @payload[:trace_id],
      name: @payload[:name] || build_name,
      kind: @payload[:kind] || "request",
      started_at: parse_timestamp(@payload[:started_at]) || now,
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
      user_id: @payload[:user_id],
      created_at: now,
      updated_at: now
    }
  end

  def create_trace!(skip_uniqueness: false)
    trace = @project.traces.new(
      trace_id: @payload[:trace_id],
      name: @payload[:name] || build_name,
      kind: @payload[:kind] || "request",
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

    # Skip uniqueness validation if we've already verified trace doesn't exist
    trace.skip_uniqueness_validation = skip_uniqueness
    trace.save!
    trace
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
        kind: span_data[:kind] || "custom",
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
      "Unknown"
    end
  end

  def normalize_path(path)
    # Replace IDs with :id for grouping
    path.gsub(/\/\d+/, "/:id").gsub(/\/[a-f0-9-]{36}/, "/:uuid")
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
        type: "trace",
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
