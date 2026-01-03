require "test_helper"

class QueryAnalyzerTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "slow_queries should find queries above threshold" do
    trace = create_test_trace(@project, started_at: Time.current)
    create_db_span(trace, duration_ms: 150, sql: "SELECT * FROM users")
    create_db_span(trace, duration_ms: 50, sql: "SELECT * FROM posts")
    create_db_span(trace, duration_ms: 200, sql: "SELECT * FROM comments")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    slow = analyzer.slow_queries(threshold_ms: 100)

    assert_equal 2, slow.length
    assert slow.all? { |q| q[:duration_ms] >= 100 }
  end

  test "slow_queries should order by duration descending" do
    trace = create_test_trace(@project, started_at: Time.current)
    create_db_span(trace, duration_ms: 150, sql: "SELECT 1")
    create_db_span(trace, duration_ms: 300, sql: "SELECT 2")
    create_db_span(trace, duration_ms: 200, sql: "SELECT 3")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    slow = analyzer.slow_queries(threshold_ms: 100)

    assert_equal 300.0, slow[0][:duration_ms]
    assert_equal 200.0, slow[1][:duration_ms]
    assert_equal 150.0, slow[2][:duration_ms]
  end

  test "slow_queries should include trace and span information" do
    trace = create_test_trace(@project, started_at: Time.current, name: "GET /users")
    span = create_db_span(trace, duration_ms: 150, sql: "SELECT * FROM users", table: "users")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    slow = analyzer.slow_queries(threshold_ms: 100)

    query = slow.first
    assert_equal span.span_id, query[:span_id]
    assert_equal trace.trace_id, query[:trace_id]
    assert_equal "SELECT * FROM users", query[:sql]
    assert_equal "users", query[:table]
    assert_equal "GET /users", query[:trace_name]
  end

  test "slow_queries should respect limit" do
    trace = create_test_trace(@project, started_at: Time.current)
    5.times { |i| create_db_span(trace, duration_ms: 150 + i, sql: "SELECT #{i}") }

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    slow = analyzer.slow_queries(threshold_ms: 100, limit: 3)

    assert_equal 3, slow.length
  end

  test "frequent_queries should group by normalized SQL pattern" do
    trace = create_test_trace(@project, started_at: Time.current)
    create_db_span(trace, duration_ms: 10, sql: "SELECT * FROM users WHERE id = 1")
    create_db_span(trace, duration_ms: 10, sql: "SELECT * FROM users WHERE id = 2")
    create_db_span(trace, duration_ms: 10, sql: "SELECT * FROM users WHERE id = 3")
    create_db_span(trace, duration_ms: 10, sql: "SELECT * FROM posts WHERE id = 1")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    frequent = analyzer.frequent_queries

    # Should have 2 unique patterns
    assert frequent.length >= 1
    # The users pattern should appear 3 times
    users_pattern = frequent.find { |p| p[:table] == "users" }
    assert_not_nil users_pattern
    assert_equal 3, users_pattern[:count]
  end

  test "frequent_queries should calculate average duration" do
    trace = create_test_trace(@project, started_at: Time.current)
    create_db_span(trace, duration_ms: 10, sql: "SELECT * FROM users WHERE id = 1")
    create_db_span(trace, duration_ms: 20, sql: "SELECT * FROM users WHERE id = 2")
    create_db_span(trace, duration_ms: 30, sql: "SELECT * FROM users WHERE id = 3")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    frequent = analyzer.frequent_queries

    users_pattern = frequent.find { |p| p[:table] == "users" }
    assert_not_nil users_pattern
    assert_equal 20.0, users_pattern[:avg_duration_ms]
  end

  test "summary should return aggregate statistics" do
    trace1 = create_test_trace(@project, started_at: Time.current)
    trace2 = create_test_trace(@project, started_at: Time.current)
    create_db_span(trace1, duration_ms: 50, sql: "SELECT * FROM users", table: "users")
    create_db_span(trace1, duration_ms: 150, sql: "SELECT * FROM posts", table: "posts")
    create_db_span(trace2, duration_ms: 550, sql: "SELECT * FROM comments", table: "comments")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    summary = analyzer.summary

    assert_equal 3, summary[:total_queries]
    assert_equal 1, summary[:slow_count]  # >= 100ms
    assert_equal 1, summary[:very_slow_count]  # >= 500ms
    assert_equal 3, summary[:table_count]
    assert_includes summary[:tables], "users"
    assert_includes summary[:tables], "posts"
    assert_includes summary[:tables], "comments"
  end

  test "summary should return empty summary when no queries" do
    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    summary = analyzer.summary

    assert_equal 0, summary[:total_queries]
    assert_equal 0, summary[:avg_duration_ms]
    assert_equal 0, summary[:slow_count]
    assert_equal [], summary[:tables]
  end

  test "table_breakdown should group by table" do
    trace = create_test_trace(@project, started_at: Time.current)
    create_db_span(trace, duration_ms: 10, sql: "SELECT 1", table: "users")
    create_db_span(trace, duration_ms: 20, sql: "SELECT 2", table: "users")
    create_db_span(trace, duration_ms: 100, sql: "SELECT 3", table: "posts")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    breakdown = analyzer.table_breakdown

    users_table = breakdown.find { |t| t[:table] == "users" }
    posts_table = breakdown.find { |t| t[:table] == "posts" }

    assert_not_nil users_table
    assert_equal 2, users_table[:count]
    assert_equal 30.0, users_table[:total_duration_ms]
    assert_equal 15.0, users_table[:avg_duration_ms]

    assert_not_nil posts_table
    assert_equal 1, posts_table[:count]
  end

  test "should respect since parameter" do
    old_trace = create_test_trace(@project, started_at: 2.hours.ago)
    create_db_span(old_trace, duration_ms: 150, sql: "SELECT old")

    recent_trace = create_test_trace(@project, started_at: 30.minutes.ago)
    create_db_span(recent_trace, duration_ms: 150, sql: "SELECT new")

    analyzer = QueryAnalyzer.new(project: @project, since: 1.hour.ago)
    slow = analyzer.slow_queries(threshold_ms: 100)

    assert_equal 1, slow.length
    assert_equal "SELECT new", slow.first[:sql]
  end

  private

  def create_db_span(trace, duration_ms:, sql:, table: nil, operation: nil)
    trace.spans.create!(
      project: @project,
      span_id: SecureRandom.hex(8),
      name: "SQL Query",
      kind: "db",
      started_at: trace.started_at,
      duration_ms: duration_ms,
      data: {
        "sql" => sql,
        "table" => table || sql.match(/FROM\s+(\w+)/i)&.[](1),
        "operation" => operation || sql.match(/^(\w+)/i)&.[](1)
      }
    )
  end
end
