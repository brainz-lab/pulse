require "test_helper"

class TraceProcessorTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "process! should create new trace" do
    payload = {
      trace_id: "abc123",
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      request_method: "GET",
      request_path: "/users",
      status: 200
    }

    assert_difference "Trace.count", 1 do
      processor = TraceProcessor.new(project: @project, payload: payload)
      processor.process!
    end

    trace = @project.traces.find_by(trace_id: "abc123")
    assert_not_nil trace
    assert_equal "GET /users", trace.name
    assert_equal "request", trace.kind
    assert_equal "GET", trace.request_method
    assert_equal "/users", trace.request_path
    assert_equal 200, trace.status
  end

  test "process! should find existing trace" do
    existing_trace = create_test_trace(@project, trace_id: "existing123")

    payload = {
      trace_id: "existing123",
      name: "GET /users",
      ended_at: Time.current.iso8601
    }

    assert_no_difference "Trace.count" do
      processor = TraceProcessor.new(project: @project, payload: payload)
      trace = processor.process!
      assert_equal existing_trace.id, trace.id
    end
  end

  test "process! should create spans with trace" do
    payload = {
      trace_id: "trace_with_spans",
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      spans: [
        {
          span_id: "span1",
          name: "SELECT users",
          kind: "db",
          started_at: Time.current.iso8601,
          ended_at: (Time.current + 0.1).iso8601,
          duration_ms: 100,
          data: { sql: "SELECT * FROM users" }
        },
        {
          span_id: "span2",
          name: "Render template",
          kind: "render",
          started_at: (Time.current + 0.1).iso8601,
          ended_at: (Time.current + 0.2).iso8601,
          duration_ms: 100,
          data: { template: "users/index.html.erb" }
        }
      ]
    }

    assert_difference "Span.count", 2 do
      processor = TraceProcessor.new(project: @project, payload: payload)
      processor.process!
    end

    trace = @project.traces.find_by(trace_id: "trace_with_spans")
    assert_equal 2, trace.spans.count
  end

  test "process! should complete trace when ended_at provided" do
    payload = {
      trace_id: "complete_trace",
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      ended_at: (Time.current + 0.5).iso8601,
      error: false
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert_not_nil trace.ended_at
    assert_equal false, trace.error
  end

  test "process! should handle error traces" do
    payload = {
      trace_id: "error_trace",
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      ended_at: (Time.current + 0.5).iso8601,
      error: true,
      error_class: "ActiveRecord::RecordNotFound",
      error_message: "Couldn't find User with id=999"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert trace.error
    assert_equal "ActiveRecord::RecordNotFound", trace.error_class
    assert_equal "Couldn't find User with id=999", trace.error_message
  end

  test "process! should handle job traces" do
    payload = {
      trace_id: "job123",
      name: "SendEmailJob",
      kind: "job",
      started_at: Time.current.iso8601,
      ended_at: (Time.current + 2).iso8601,
      job_class: "SendEmailJob",
      job_id: "job_abc123",
      queue: "default",
      queue_wait_ms: 50,
      executions: 1
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert_equal "job", trace.kind
    assert_equal "SendEmailJob", trace.job_class
    assert_equal "job_abc123", trace.job_id
    assert_equal "default", trace.queue
    assert_equal 50, trace.queue_wait_ms
    assert_equal 1, trace.executions
  end

  test "process! should build name from request data if not provided" do
    payload = {
      trace_id: "auto_name",
      kind: "request",
      started_at: Time.current.iso8601,
      request_method: "POST",
      request_path: "/api/users"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert_equal "POST /api/users", trace.name
  end

  test "process! should normalize path with IDs" do
    payload = {
      trace_id: "normalized",
      kind: "request",
      started_at: Time.current.iso8601,
      request_method: "GET",
      request_path: "/users/123/posts/456"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    # Path should be normalized to /users/:id/posts/:id
    assert_equal "GET /users/:id/posts/:id", trace.name
  end

  test "process! should normalize path with UUIDs" do
    uuid = SecureRandom.uuid
    payload = {
      trace_id: "normalized_uuid",
      kind: "request",
      started_at: Time.current.iso8601,
      request_method: "GET",
      request_path: "/resources/#{uuid}"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert_equal "GET /resources/:uuid", trace.name
  end

  test "process! should build name from job_class if provided" do
    payload = {
      trace_id: "job_name",
      kind: "job",
      started_at: Time.current.iso8601,
      job_class: "ProcessDataJob"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert_equal "ProcessDataJob", trace.name
  end

  test "process! should default name to Unknown if no data" do
    payload = {
      trace_id: "unknown",
      kind: "custom",
      started_at: Time.current.iso8601
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert_equal "Unknown", trace.name
  end

  test "process! should handle timestamp formats" do
    # ISO8601 string
    payload = {
      trace_id: "iso_time",
      name: "Test",
      kind: "request",
      started_at: "2024-01-15T10:30:00Z"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!
    assert_not_nil trace.started_at

    # Unix timestamp
    payload = {
      trace_id: "unix_time",
      name: "Test",
      kind: "request",
      started_at: Time.current.to_i
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!
    assert_not_nil trace.started_at
  end

  test "process! should handle span data correctly" do
    payload = {
      trace_id: "span_data",
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      spans: [
        {
          span_id: "span1",
          name: "Query",
          kind: "db",
          started_at: Time.current.iso8601,
          data: { sql: "SELECT * FROM users", table: "users", operation: "SELECT" }
        }
      ]
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    span = trace.spans.first
    assert_not_nil span.data
    assert_kind_of Hash, span.data
    assert_equal "SELECT * FROM users", span.data["sql"]
    assert_equal "users", span.data["table"]
  end

  test "process! should set span duration from timestamps if not provided" do
    started = Time.current
    ended = started + 0.15

    payload = {
      trace_id: "span_duration",
      name: "GET /users",
      kind: "request",
      started_at: started.iso8601,
      spans: [
        {
          span_id: "span1",
          name: "Query",
          kind: "db",
          started_at: started.iso8601,
          ended_at: ended.iso8601
        }
      ]
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    span = trace.spans.first
    # Duration should be calculated from timestamps if not provided
    assert_not_nil span.duration_ms
  end

  test "process! should handle invalid timestamps gracefully" do
    payload = {
      trace_id: "invalid_time",
      name: "Test",
      kind: "request",
      started_at: "not a valid timestamp",
      ended_at: "also invalid"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)

    # Should not raise an error, uses current time as fallback
    assert_nothing_raised do
      processor.process!
    end
  end

  test "process! should store metadata fields" do
    payload = {
      trace_id: "metadata",
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      environment: "production",
      commit: "abc123def",
      host: "web-1",
      user_id: "user_456"
    }

    processor = TraceProcessor.new(project: @project, payload: payload)
    trace = processor.process!

    assert_equal "production", trace.environment
    assert_equal "abc123def", trace.commit
    assert_equal "web-1", trace.host
    assert_equal "user_456", trace.user_id
  end
end
