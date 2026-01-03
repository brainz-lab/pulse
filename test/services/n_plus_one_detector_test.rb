require "test_helper"

class NPlusOneDetectorTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "analyze_trace should detect N+1 patterns" do
    trace = create_test_trace(@project, started_at: Time.current)

    # Create N+1 pattern: 5 identical queries
    5.times do |i|
      create_db_span(trace, sql: "SELECT * FROM users WHERE id = #{i}")
    end

    detector = NPlusOneDetector.new(project: @project)
    patterns = detector.analyze_trace(trace)

    assert_equal 1, patterns.length
    pattern = patterns.first
    assert_equal 5, pattern[:count]
    assert_includes pattern[:normalized_sql], "SELECT * FROM users WHERE id"
  end

  test "analyze_trace should not flag unique queries" do
    trace = create_test_trace(@project, started_at: Time.current)

    create_db_span(trace, sql: "SELECT * FROM users")
    create_db_span(trace, sql: "SELECT * FROM posts")
    create_db_span(trace, sql: "SELECT * FROM comments")

    detector = NPlusOneDetector.new(project: @project)
    patterns = detector.analyze_trace(trace)

    assert_empty patterns
  end

  test "analyze_trace should require minimum repeat count" do
    trace = create_test_trace(@project, started_at: Time.current)

    # Only 2 repeated queries (below minimum of 3)
    2.times { create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1") }

    detector = NPlusOneDetector.new(project: @project)
    patterns = detector.analyze_trace(trace)

    assert_empty patterns
  end

  test "analyze_trace should calculate total and average duration" do
    trace = create_test_trace(@project, started_at: Time.current)

    # Create 4 queries with known durations
    [10, 20, 30, 40].each do |duration|
      create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", duration_ms: duration)
    end

    detector = NPlusOneDetector.new(project: @project)
    patterns = detector.analyze_trace(trace)

    pattern = patterns.first
    assert_equal 4, pattern[:count]
    assert_equal 100.0, pattern[:total_duration_ms]
    assert_equal 25.0, pattern[:avg_duration_ms]
  end

  test "analyze_trace should include span_ids" do
    trace = create_test_trace(@project, started_at: Time.current)

    spans = 3.times.map do
      create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1")
    end

    detector = NPlusOneDetector.new(project: @project)
    patterns = detector.analyze_trace(trace)

    pattern = patterns.first
    assert_equal 3, pattern[:span_ids].length
    spans.each { |span| assert_includes pattern[:span_ids], span.span_id }
  end

  test "find_affected_traces should find traces with N+1 patterns" do
    # Create trace with N+1 pattern
    affected_trace = create_test_trace(@project, started_at: Time.current, name: "GET /users")
    affected_trace.update!(span_count: 5)
    5.times { create_db_span(affected_trace, sql: "SELECT * FROM posts WHERE user_id = 1") }

    # Create trace without N+1 pattern
    clean_trace = create_test_trace(@project, started_at: Time.current, name: "GET /home")
    clean_trace.update!(span_count: 2)
    create_db_span(clean_trace, sql: "SELECT * FROM users")
    create_db_span(clean_trace, sql: "SELECT * FROM settings")

    detector = NPlusOneDetector.new(project: @project, since: 1.hour.ago)
    affected = detector.find_affected_traces

    assert_equal 1, affected.length
    assert_equal affected_trace.id, affected.first[:trace].id
    assert affected.first[:patterns].any?
  end

  test "find_affected_traces should calculate potential savings" do
    trace = create_test_trace(@project, started_at: Time.current)
    trace.update!(span_count: 10)

    # 10 queries at 10ms each = 100ms total
    # If optimized to 1 query, savings = 90ms
    10.times { create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", duration_ms: 10) }

    detector = NPlusOneDetector.new(project: @project, since: 1.hour.ago)
    affected = detector.find_affected_traces

    result = affected.first
    assert_not_nil result[:potential_savings_ms]
    assert result[:potential_savings_ms] > 0
  end

  test "find_affected_traces should respect limit" do
    5.times do |i|
      trace = create_test_trace(@project, started_at: Time.current - i.minutes)
      trace.update!(span_count: 5)
      5.times { create_db_span(trace, sql: "SELECT * FROM users WHERE id = #{i}") }
    end

    detector = NPlusOneDetector.new(project: @project, since: 1.hour.ago)
    affected = detector.find_affected_traces(limit: 3)

    assert_equal 3, affected.length
  end

  test "aggregate_patterns should group patterns across traces" do
    # Create two traces with the same N+1 pattern
    2.times do
      trace = create_test_trace(@project, started_at: Time.current)
      trace.update!(span_count: 4)
      4.times { create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1") }
    end

    detector = NPlusOneDetector.new(project: @project, since: 1.hour.ago)
    aggregated = detector.aggregate_patterns

    assert_equal 1, aggregated.length
    pattern = aggregated.first
    assert_equal 8, pattern[:count]  # 4 queries x 2 traces
    assert_equal 2, pattern[:trace_count]
  end

  test "aggregate_patterns should respect limit" do
    # Create 5 different patterns
    5.times do |i|
      trace = create_test_trace(@project, started_at: Time.current)
      trace.update!(span_count: 3)
      3.times { create_db_span(trace, sql: "SELECT * FROM table_#{i} WHERE id = 1") }
    end

    detector = NPlusOneDetector.new(project: @project, since: 1.hour.ago)
    aggregated = detector.aggregate_patterns(limit: 3)

    assert_equal 3, aggregated.length
  end

  test "should respect since parameter" do
    old_trace = create_test_trace(@project, started_at: 2.hours.ago)
    old_trace.update!(span_count: 5)
    5.times { create_db_span(old_trace, sql: "SELECT * FROM old WHERE id = 1") }

    recent_trace = create_test_trace(@project, started_at: 30.minutes.ago)
    recent_trace.update!(span_count: 5)
    5.times { create_db_span(recent_trace, sql: "SELECT * FROM new WHERE id = 1") }

    detector = NPlusOneDetector.new(project: @project, since: 1.hour.ago)
    affected = detector.find_affected_traces

    assert_equal 1, affected.length
    assert_equal recent_trace.id, affected.first[:trace].id
  end

  private

  def create_db_span(trace, sql:, duration_ms: 10)
    trace.spans.create!(
      project: @project,
      span_id: SecureRandom.hex(8),
      name: "SQL Query",
      kind: "db",
      started_at: trace.started_at,
      duration_ms: duration_ms,
      data: {
        "sql" => sql,
        "table" => sql.match(/FROM\s+(\w+)/i)&.[](1),
        "operation" => sql.match(/^(\w+)/i)&.[](1)
      }
    )
  end
end
