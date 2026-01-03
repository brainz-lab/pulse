require "test_helper"

class Mcp::ToolsTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  # PulseOverview tests
  test "PulseOverview should return health metrics" do
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    tool = Mcp::Tools::PulseOverview.new(@project)
    result = tool.call({})

    assert_not_nil result[:apdex]
    assert_not_nil result[:throughput]
    assert_not_nil result[:rpm]
    assert_not_nil result[:error_rate]
  end

  test "PulseOverview should respect since parameter" do
    # Old trace
    create_test_trace(@project,
      kind: "request",
      started_at: 2.hours.ago,
      ended_at: 2.hours.ago + 0.1,
      duration_ms: 100
    )
    # Recent trace
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    tool = Mcp::Tools::PulseOverview.new(@project)
    result = tool.call(since: "1h")

    assert_equal 1, result[:throughput]
  end

  # PulseSlowRequests tests
  test "PulseSlowRequests should find slow requests" do
    create_test_trace(@project,
      name: "GET /slow",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 2,
      duration_ms: 2000
    )
    create_test_trace(@project,
      name: "GET /fast",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    tool = Mcp::Tools::PulseSlowRequests.new(@project)
    result = tool.call(threshold_ms: 1000)

    assert_equal 1, result[:count]
    assert_equal "GET /slow", result[:slow_requests].first[:name]
  end

  test "PulseSlowRequests should order by duration descending" do
    create_test_trace(@project,
      name: "Slowest",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 5,
      duration_ms: 5000
    )
    create_test_trace(@project,
      name: "Slower",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 3,
      duration_ms: 3000
    )

    tool = Mcp::Tools::PulseSlowRequests.new(@project)
    result = tool.call(threshold_ms: 1000)

    assert_equal "Slowest", result[:slow_requests][0][:name]
    assert_equal "Slower", result[:slow_requests][1][:name]
  end

  test "PulseSlowRequests should respect limit" do
    5.times do |i|
      create_test_trace(@project,
        name: "Slow #{i}",
        kind: "request",
        started_at: 30.minutes.ago,
        ended_at: 30.minutes.ago + 2,
        duration_ms: 2000 + i * 100
      )
    end

    tool = Mcp::Tools::PulseSlowRequests.new(@project)
    result = tool.call(threshold_ms: 1000, limit: 3)

    assert_equal 3, result[:slow_requests].length
  end

  # PulseErrors tests
  test "PulseErrors should find error traces" do
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100,
      error: true
    )
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100,
      error: false
    )

    tool = Mcp::Tools::PulseErrors.new(@project)
    result = tool.call({})

    assert_equal 1, result[:count]
  end

  test "PulseErrors should include error details" do
    trace = @project.traces.create!(
      trace_id: SecureRandom.hex(16),
      name: "GET /error",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100,
      error: true,
      error_class: "ActiveRecord::RecordNotFound",
      error_message: "Couldn't find User with id=999"
    )

    tool = Mcp::Tools::PulseErrors.new(@project)
    result = tool.call({})

    error_trace = result[:error_traces].first
    assert_equal "ActiveRecord::RecordNotFound", error_trace[:error_class]
    assert_includes error_trace[:error_message], "Couldn't find User"
  end

  # PulseTrace tests
  test "PulseTrace should return trace details" do
    trace = create_test_trace(@project,
      trace_id: "detailed_trace_123",
      name: "GET /users",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.5,
      duration_ms: 500
    )

    tool = Mcp::Tools::PulseTrace.new(@project)
    result = tool.call(trace_id: "detailed_trace_123")

    assert_equal "detailed_trace_123", result[:trace][:trace_id]
    assert_equal "GET /users", result[:trace][:name]
    assert_equal 500, result[:trace][:duration_ms]
  end

  test "PulseTrace should include spans waterfall" do
    trace = create_test_trace(@project,
      trace_id: "trace_with_spans",
      name: "GET /users",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.5,
      duration_ms: 500
    )
    create_test_span(trace, name: "DB Query", kind: "db", duration_ms: 50)
    create_test_span(trace, name: "Render View", kind: "render", duration_ms: 100)

    tool = Mcp::Tools::PulseTrace.new(@project)
    result = tool.call(trace_id: "trace_with_spans")

    assert_equal 2, result[:spans].length
  end

  test "PulseTrace should return error for non-existent trace" do
    tool = Mcp::Tools::PulseTrace.new(@project)
    result = tool.call(trace_id: "non_existent")

    assert_equal "Trace not found", result[:error]
  end

  # Base tool tests
  test "Base parse_since should parse minute format" do
    tool = Mcp::Tools::PulseOverview.new(@project)
    since = tool.send(:parse_since, "30m")

    assert_in_delta 30.minutes.ago.to_i, since.to_i, 2
  end

  test "Base parse_since should parse hour format" do
    tool = Mcp::Tools::PulseOverview.new(@project)
    since = tool.send(:parse_since, "24h")

    assert_in_delta 24.hours.ago.to_i, since.to_i, 2
  end

  test "Base parse_since should parse day format" do
    tool = Mcp::Tools::PulseOverview.new(@project)
    since = tool.send(:parse_since, "7d")

    assert_in_delta 7.days.ago.to_i, since.to_i, 2
  end

  test "Base parse_since should default to 1 hour" do
    tool = Mcp::Tools::PulseOverview.new(@project)
    since = tool.send(:parse_since, "invalid")

    assert_in_delta 1.hour.ago.to_i, since.to_i, 2
  end
end
