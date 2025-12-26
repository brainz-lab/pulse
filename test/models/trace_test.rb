require "test_helper"

class TraceTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @trace = create_test_trace(@project)
  end

  test "should be valid with valid attributes" do
    assert @trace.valid?
  end

  test "should require trace_id" do
    trace = Trace.new(project: @project, name: "Test", kind: "request", started_at: Time.current)
    assert_not trace.valid?
    assert_includes trace.errors[:trace_id], "can't be blank"
  end

  test "should require unique trace_id" do
    duplicate = Trace.new(
      project: @project,
      trace_id: @trace.trace_id,
      name: "Test",
      kind: "request",
      started_at: Time.current
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:trace_id], "has already been taken"
  end

  test "should require name" do
    trace = Trace.new(project: @project, trace_id: "abc123", kind: "request", started_at: Time.current)
    assert_not trace.valid?
    assert_includes trace.errors[:name], "can't be blank"
  end

  test "should validate kind inclusion" do
    trace = Trace.new(
      project: @project,
      trace_id: "test123",
      name: "Test",
      kind: "invalid",
      started_at: Time.current
    )
    assert_not trace.valid?
    assert_includes trace.errors[:kind], "is not included in the list"
  end

  test "should accept valid kinds" do
    Trace::KINDS.each do |kind|
      trace = Trace.new(
        project: @project,
        trace_id: "test_#{kind}",
        name: "Test",
        kind: kind,
        started_at: Time.current
      )
      assert trace.valid?, "#{kind} should be a valid kind"
    end
  end

  test "should require started_at" do
    trace = Trace.new(project: @project, trace_id: "abc123", name: "Test", kind: "request")
    assert_not trace.valid?
    assert_includes trace.errors[:started_at], "can't be blank"
  end

  test "should belong to project" do
    assert_equal @project, @trace.project
  end

  test "should have many spans" do
    span = create_test_span(@trace)
    assert_includes @trace.spans, span
  end

  test "should destroy associated spans on destroy" do
    span = create_test_span(@trace)
    span_id = span.id

    @trace.destroy

    assert_nil Span.find_by(id: span_id)
  end

  test "scope requests should filter request traces" do
    job_trace = create_test_trace(@project, trace_id: "job1", kind: "job")

    requests = @project.traces.requests
    assert_includes requests, @trace
    assert_not_includes requests, job_trace
  end

  test "scope jobs should filter job traces" do
    job_trace = create_test_trace(@project, trace_id: "job1", kind: "job")

    jobs = @project.traces.jobs
    assert_includes jobs, job_trace
    assert_not_includes jobs, @trace
  end

  test "scope recent should order by started_at desc" do
    # Update the setup trace with a specific time
    @trace.update!(started_at: 45.minutes.ago)

    trace1 = create_test_trace(@project, trace_id: "t1", started_at: 1.hour.ago)
    trace2 = create_test_trace(@project, trace_id: "t2", started_at: 2.hours.ago)
    trace3 = create_test_trace(@project, trace_id: "t3", started_at: 30.minutes.ago)

    recent = @project.traces.recent.to_a
    assert_equal trace3.id, recent[0].id
    assert_equal @trace.id, recent[1].id
    assert_equal trace1.id, recent[2].id
    assert_equal trace2.id, recent[3].id
  end

  test "scope slow should filter traces above threshold" do
    fast_trace = create_test_trace(@project, trace_id: "fast", duration_ms: 500)
    slow_trace = create_test_trace(@project, trace_id: "slow", duration_ms: 2000)

    slow_traces = @project.traces.slow(1000)
    assert_includes slow_traces, slow_trace
    assert_not_includes slow_traces, fast_trace
  end

  test "scope errors should filter error traces" do
    error_trace = create_test_trace(@project, trace_id: "error1", error: true)

    errors = @project.traces.errors
    assert_includes errors, error_trace
    assert_not_includes errors, @trace
  end

  test "complete! should update trace with end information" do
    ended_at = Time.current
    @trace.complete!(
      ended_at: ended_at,
      error: true,
      error_class: "StandardError",
      error_message: "Test error"
    )

    @trace.reload
    assert_equal ended_at.to_i, @trace.ended_at.to_i
    assert @trace.error
    assert_equal "StandardError", @trace.error_class
    assert_equal "Test error", @trace.error_message
  end

  test "calculate_duration should set duration_ms on save" do
    started = Time.current
    ended = started + 0.5  # 500ms

    trace = create_test_trace(@project,
      trace_id: "duration_test",
      started_at: started,
      ended_at: ended
    )

    assert_equal 500.0, trace.duration_ms
  end

  test "add_span! should create span and update metrics" do
    @trace.update!(ended_at: Time.current + 1.second, duration_ms: 1000)

    span = @trace.add_span!(
      span_id: "span1",
      name: "SELECT users",
      kind: "db",
      started_at: @trace.started_at,
      ended_at: @trace.started_at + 0.1,
      duration_ms: 100
    )

    assert span.persisted?
    assert_equal @trace, span.trace
    assert_equal @project, span.project

    @trace.reload
    assert_equal 1, @trace.span_count
    assert_equal 100, @trace.db_duration_ms
  end

  test "waterfall should return formatted span data" do
    @trace.update!(started_at: Time.current, ended_at: Time.current + 1, duration_ms: 1000)

    span1 = create_test_span(@trace,
      span_id: "span1",
      started_at: @trace.started_at,
      duration_ms: 100
    )

    span2 = create_test_span(@trace,
      span_id: "span2",
      started_at: @trace.started_at + 0.1,
      duration_ms: 50,
      parent_span_id: "span1"
    )

    # Verify spans were created
    assert_equal 2, @trace.spans.count

    @trace.spans.reload
    waterfall = @trace.waterfall

    assert_equal 2, waterfall.length
    # Check the waterfall contains the right span IDs
    span_ids = waterfall.map { |w| w[:id] }.compact
    assert_includes span_ids, "span1"
    assert_includes span_ids, "span2"
    # Verify spans are ordered by started_at
    assert_equal "span1", waterfall.first[:id]
    assert_equal "span2", waterfall.last[:id]
    # Verify waterfall data structure
    assert_not_nil waterfall.first[:duration_ms]
    assert_not_nil waterfall.first[:offset_ms]
  end

  test "apdex_category should return satisfied for fast traces" do
    @trace.update!(duration_ms: 300)  # 0.3s, threshold is 0.5s
    assert_equal :satisfied, @trace.apdex_category
  end

  test "apdex_category should return tolerating for medium traces" do
    @trace.update!(duration_ms: 1000)  # 1s, between 0.5s and 2s
    assert_equal :tolerating, @trace.apdex_category
  end

  test "apdex_category should return frustrated for slow traces" do
    @trace.update!(duration_ms: 3000)  # 3s, above 2s (4 * 0.5s)
    assert_equal :frustrated, @trace.apdex_category
  end

  test "recalculate_span_metrics! should aggregate span durations" do
    @trace.update!(ended_at: Time.current + 1, duration_ms: 1000)

    create_test_span(@trace, kind: "db", duration_ms: 100)
    create_test_span(@trace, kind: "db", duration_ms: 50)
    create_test_span(@trace, kind: "render", duration_ms: 200)
    create_test_span(@trace, kind: "http", duration_ms: 150)

    @trace.send(:recalculate_span_metrics!)
    @trace.reload

    assert_equal 4, @trace.span_count
    assert_equal 150, @trace.db_duration_ms
    assert_equal 200, @trace.view_duration_ms
    assert_equal 150, @trace.external_duration_ms
  end
end
