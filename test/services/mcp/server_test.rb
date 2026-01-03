require "test_helper"

class Mcp::ServerTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @server = Mcp::Server.new(@project)
  end

  test "list_tools should return all registered tools" do
    tools = @server.list_tools

    assert_equal 7, tools.length

    tool_names = tools.map { |t| t[:name] }
    assert_includes tool_names, "pulse_overview"
    assert_includes tool_names, "pulse_slow_requests"
    assert_includes tool_names, "pulse_throughput"
    assert_includes tool_names, "pulse_errors"
    assert_includes tool_names, "pulse_trace"
    assert_includes tool_names, "pulse_endpoints"
    assert_includes tool_names, "pulse_metrics"
  end

  test "list_tools should include description and schema for each tool" do
    tools = @server.list_tools

    tools.each do |tool|
      assert_not_nil tool[:name]
      assert_not_nil tool[:description]
      assert_not_nil tool[:inputSchema]
      assert_kind_of String, tool[:description]
      assert_kind_of Hash, tool[:inputSchema]
    end
  end

  test "call_tool should call pulse_overview" do
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    result = @server.call_tool("pulse_overview")

    assert_not_nil result[:apdex]
    assert_not_nil result[:throughput]
    assert_not_nil result[:error_rate]
  end

  test "call_tool should call pulse_slow_requests" do
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 2,
      duration_ms: 2000
    )

    result = @server.call_tool("pulse_slow_requests", threshold_ms: 1000)

    assert_not_nil result[:slow_requests]
    assert_equal 1, result[:count]
  end

  test "call_tool should call pulse_errors" do
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100,
      error: true
    )

    result = @server.call_tool("pulse_errors")

    assert_not_nil result[:error_traces]
    assert_equal 1, result[:count]
  end

  test "call_tool should call pulse_trace with trace_id" do
    trace = create_test_trace(@project,
      trace_id: "test_trace_123",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    result = @server.call_tool("pulse_trace", trace_id: "test_trace_123")

    assert_not_nil result[:trace]
    assert_equal "test_trace_123", result[:trace][:trace_id]
  end

  test "call_tool should raise error for unknown tool" do
    assert_raises RuntimeError do
      @server.call_tool("unknown_tool")
    end
  end

  test "call_tool should pass arguments to tool" do
    5.times do
      create_test_trace(@project,
        kind: "request",
        started_at: 30.minutes.ago,
        ended_at: 30.minutes.ago + 2,
        duration_ms: 2000
      )
    end

    result = @server.call_tool("pulse_slow_requests", limit: 2, threshold_ms: 500)

    assert_equal 2, result[:slow_requests].length
  end
end
