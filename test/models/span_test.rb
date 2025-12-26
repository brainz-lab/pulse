require "test_helper"

class SpanTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @trace = create_test_trace(@project, ended_at: Time.current, duration_ms: 100)
    @span = create_test_span(@trace)
  end

  test "should be valid with valid attributes" do
    assert @span.valid?
  end

  test "should require span_id" do
    span = Span.new(
      trace: @trace,
      project: @project,
      name: "Test",
      kind: "db",
      started_at: Time.current
    )
    assert_not span.valid?
    assert_includes span.errors[:span_id], "can't be blank"
  end

  test "should require name" do
    span = Span.new(
      trace: @trace,
      project: @project,
      span_id: "span123",
      kind: "db",
      started_at: Time.current
    )
    assert_not span.valid?
    assert_includes span.errors[:name], "can't be blank"
  end

  test "should validate kind inclusion" do
    span = Span.new(
      trace: @trace,
      project: @project,
      span_id: "span123",
      name: "Test",
      kind: "invalid",
      started_at: Time.current
    )
    assert_not span.valid?
    assert_includes span.errors[:kind], "is not included in the list"
  end

  test "should accept all valid kinds" do
    Span::KINDS.each do |kind|
      span = Span.new(
        trace: @trace,
        project: @project,
        span_id: "span_#{kind}",
        name: "Test",
        kind: kind,
        started_at: Time.current
      )
      assert span.valid?, "#{kind} should be a valid kind"
    end
  end

  test "should require started_at" do
    span = Span.new(
      trace: @trace,
      project: @project,
      span_id: "span123",
      name: "Test",
      kind: "db"
    )
    assert_not span.valid?
    assert_includes span.errors[:started_at], "can't be blank"
  end

  test "should belong to trace" do
    assert_equal @trace, @span.trace
  end

  test "should belong to project" do
    assert_equal @project, @span.project
  end

  test "scope db_spans should filter database spans" do
    db_span = create_test_span(@trace, span_id: "db1", kind: "db")
    http_span = create_test_span(@trace, span_id: "http1", kind: "http")

    db_spans = @trace.spans.db_spans
    assert_includes db_spans, db_span
    assert_not_includes db_spans, http_span
  end

  test "scope http_spans should filter http spans" do
    db_span = create_test_span(@trace, span_id: "db1", kind: "db")
    http_span = create_test_span(@trace, span_id: "http1", kind: "http")

    http_spans = @trace.spans.http_spans
    assert_includes http_spans, http_span
    assert_not_includes http_spans, db_span
  end

  test "scope cache_spans should filter cache spans" do
    cache_span = create_test_span(@trace, span_id: "cache1", kind: "cache")
    db_span = create_test_span(@trace, span_id: "db1", kind: "db")

    cache_spans = @trace.spans.cache_spans
    assert_includes cache_spans, cache_span
    assert_not_includes cache_spans, db_span
  end

  test "scope slow should filter spans above threshold" do
    fast_span = create_test_span(@trace, span_id: "fast", duration_ms: 50)
    slow_span = create_test_span(@trace, span_id: "slow", duration_ms: 200)

    slow_spans = @trace.spans.slow(100)
    assert_includes slow_spans, slow_span
    assert_not_includes slow_spans, fast_span
  end

  test "calculate_duration should set duration_ms on save" do
    started = Time.current
    ended = started + 0.25  # 250ms

    span = create_test_span(@trace,
      span_id: "duration_test",
      started_at: started,
      ended_at: ended
    )

    assert_equal 250.0, span.duration_ms
  end

  test "display_name should format db spans" do
    span = create_test_span(@trace,
      kind: "db",
      name: "SELECT users",
      data: { "operation" => "SELECT", "table" => "users" }
    )

    assert_equal "SELECT users", span.display_name
  end

  test "display_name should format http spans" do
    span = create_test_span(@trace,
      kind: "http",
      name: "API call",
      data: { "method" => "POST", "url" => "https://api.example.com/users" }
    )

    assert_equal "POST https://api.example.com/users", span.display_name
  end

  test "display_name should format cache hit spans" do
    span = create_test_span(@trace,
      kind: "cache",
      name: "Cache read",
      data: { "hit" => true, "key" => "user:123" }
    )

    assert_equal "Cache HIT: user:123", span.display_name
  end

  test "display_name should format cache miss spans" do
    span = create_test_span(@trace,
      kind: "cache",
      name: "Cache read",
      data: { "hit" => false, "key" => "user:456" }
    )

    assert_equal "Cache MISS: user:456", span.display_name
  end

  test "display_name should format render spans" do
    span = create_test_span(@trace,
      kind: "render",
      name: "Render template",
      data: { "template" => "users/show.html.erb" }
    )

    assert_equal "Render users/show.html.erb", span.display_name
  end

  test "display_name should return name for other kinds" do
    span = create_test_span(@trace,
      kind: "custom",
      name: "Custom Operation"
    )

    assert_equal "Custom Operation", span.display_name
  end

  test "display_name should handle missing data fields" do
    span = create_test_span(@trace,
      kind: "db",
      name: "Query",
      data: {}
    )

    assert_equal "SQL", span.display_name
  end
end
