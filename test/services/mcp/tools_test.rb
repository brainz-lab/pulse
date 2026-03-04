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

  # PulseServiceMap tests
  test "PulseServiceMap should return app node" do
    tool = Mcp::Tools::PulseServiceMap.new(@project)
    result = tool.call({})

    assert_includes result[:nodes].keys, @project.name
    assert_equal "app", result[:nodes][@project.name][:type]
  end

  test "PulseServiceMap should detect external HTTP dependencies" do
    trace = create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.5,
      duration_ms: 500
    )
    create_test_span(trace, name: "HTTP GET", kind: "http", duration_ms: 100,
      data: { "host" => "api.stripe.com" })
    create_test_span(trace, name: "HTTP POST", kind: "http", duration_ms: 200,
      data: { "host" => "api.stripe.com" })

    tool = Mcp::Tools::PulseServiceMap.new(@project)
    result = tool.call({})

    assert_includes result[:nodes].keys, "api.stripe.com"
    assert_equal "external_service", result[:nodes]["api.stripe.com"][:type]
    stripe_edge = result[:edges].find { |e| e[:to] == "api.stripe.com" }
    assert_not_nil stripe_edge
    assert_equal 2, stripe_edge[:calls]
  end

  test "PulseServiceMap should detect database spans" do
    trace = create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.5,
      duration_ms: 500
    )
    create_test_span(trace, name: "SELECT users", kind: "db", duration_ms: 10)

    tool = Mcp::Tools::PulseServiceMap.new(@project)
    result = tool.call({})

    assert_includes result[:nodes].keys, "database"
    assert_equal "database", result[:nodes]["database"][:type]
  end

  # PulseCompare tests
  test "PulseCompare should return metrics with deltas" do
    # Period A traces (last 1h)
    3.times do
      create_test_trace(@project,
        kind: "request",
        started_at: 30.minutes.ago,
        ended_at: 30.minutes.ago + 0.2,
        duration_ms: 200
      )
    end
    # Period B traces (last 24h but older than 1h)
    5.times do
      create_test_trace(@project,
        kind: "request",
        started_at: 12.hours.ago,
        ended_at: 12.hours.ago + 0.1,
        duration_ms: 100
      )
    end

    tool = Mcp::Tools::PulseCompare.new(@project)
    result = tool.call(period_a: "1h", period_b: "24h")

    assert_equal "1h", result[:period_a]
    assert_equal "24h", result[:period_b]
    assert result[:metrics].key?(:throughput)
  end

  test "PulseCompare should return empty metrics when no data" do
    tool = Mcp::Tools::PulseCompare.new(@project)
    result = tool.call(period_a: "1h", period_b: "24h")

    assert_equal({}, result[:metrics])
  end

  # PulseRootCause tests
  test "PulseRootCause should analyze high_latency" do
    create_test_trace(@project,
      name: "GET /slow",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 5,
      duration_ms: 5000
    )

    tool = Mcp::Tools::PulseRootCause.new(@project)
    result = tool.call(symptom: "high_latency")

    assert_equal "high_latency", result[:symptom]
    assert_not_empty result[:top_slow_endpoints]
    assert_equal "GET /slow", result[:top_slow_endpoints].first[:endpoint]
  end

  test "PulseRootCause should analyze high_errors" do
    create_test_trace(@project,
      name: "GET /fail",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100,
      error: true
    )

    tool = Mcp::Tools::PulseRootCause.new(@project)
    result = tool.call(symptom: "high_errors")

    assert_equal "high_errors", result[:symptom]
    assert_not_empty result[:top_error_endpoints]
    assert_equal "GET /fail", result[:top_error_endpoints].first[:endpoint]
  end

  test "PulseRootCause should analyze low_apdex" do
    # Create a frustrated trace (duration > 4T where T=0.5s, so > 2000ms)
    create_test_trace(@project,
      name: "GET /frustrated",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 5,
      duration_ms: 5000
    )

    tool = Mcp::Tools::PulseRootCause.new(@project)
    result = tool.call(symptom: "low_apdex")

    assert_equal "low_apdex", result[:symptom]
    assert_not_nil result[:threshold_ms]
    assert_not_empty result[:top_frustrated_endpoints]
  end

  # PulseSloStatus tests
  test "PulseSloStatus should return helpful message when SLOs not available" do
    tool = Mcp::Tools::PulseSloStatus.new(@project)
    result = tool.call({})

    assert_not_nil result[:message]
  end

  # PulseDeployImpact tests
  test "PulseDeployImpact should return helpful message when deploys not available" do
    tool = Mcp::Tools::PulseDeployImpact.new(@project)
    result = tool.call({})

    assert_not_nil result[:message]
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
