require "test_helper"

class ApdexCalculatorTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project(apdex_t: 0.5)  # 500ms threshold
  end

  test "calculate should return 1.0 for empty trace set" do
    traces = Trace.none
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 1.0, apdex
  end

  test "calculate should return 1.0 for all satisfied traces" do
    # All traces under threshold (500ms)
    create_test_trace(@project, trace_id: "t1", duration_ms: 100)
    create_test_trace(@project, trace_id: "t2", duration_ms: 300)
    create_test_trace(@project, trace_id: "t3", duration_ms: 500)

    traces = @project.traces
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 1.0, apdex
  end

  test "calculate should return 0.5 for all tolerating traces" do
    # All traces between threshold and 4x threshold (500ms - 2000ms)
    create_test_trace(@project, trace_id: "t1", duration_ms: 600)
    create_test_trace(@project, trace_id: "t2", duration_ms: 1000)
    create_test_trace(@project, trace_id: "t3", duration_ms: 2000)

    traces = @project.traces
    # Apdex = (0 + 3/2) / 3 = 1.5 / 3 = 0.5
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 0.5, apdex
  end

  test "calculate should return 0.0 for all frustrated traces" do
    # All traces over 4x threshold (> 2000ms)
    create_test_trace(@project, trace_id: "t1", duration_ms: 2500)
    create_test_trace(@project, trace_id: "t2", duration_ms: 3000)
    create_test_trace(@project, trace_id: "t3", duration_ms: 5000)

    traces = @project.traces
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 0.0, apdex
  end

  test "calculate should correctly mix satisfied and tolerating traces" do
    # 2 satisfied (<=500ms)
    create_test_trace(@project, trace_id: "t1", duration_ms: 200)
    create_test_trace(@project, trace_id: "t2", duration_ms: 400)

    # 1 tolerating (500ms < x <= 2000ms)
    create_test_trace(@project, trace_id: "t3", duration_ms: 1000)

    # 1 frustrated (>2000ms)
    create_test_trace(@project, trace_id: "t4", duration_ms: 3000)

    traces = @project.traces
    # Apdex = (2 + 1/2) / 4 = 2.5 / 4 = 0.625, rounded to 0.63
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 0.63, apdex
  end

  test "calculate should handle different thresholds" do
    # Create traces with fixed durations
    create_test_trace(@project, trace_id: "t1", duration_ms: 500)
    create_test_trace(@project, trace_id: "t2", duration_ms: 1500)
    create_test_trace(@project, trace_id: "t3", duration_ms: 5000)

    traces = @project.traces

    # With 0.5s threshold (500ms)
    # t1: satisfied (500ms <= 500ms)
    # t2: tolerating (500ms < 1500ms <= 2000ms)
    # t3: frustrated (5000ms > 2000ms)
    # Apdex = (1 + 0.5) / 3 = 0.5
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 0.5, apdex

    # With 1.0s threshold (1000ms)
    # t1: satisfied (500ms <= 1000ms)
    # t2: tolerating (1000ms < 1500ms <= 4000ms)
    # t3: frustrated (5000ms > 4000ms)
    # Apdex = (1 + 0.5) / 3 = 0.5
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 1.0)
    assert_equal 0.5, apdex

    # With 2.0s threshold (2000ms)
    # t1: satisfied (500ms <= 2000ms)
    # t2: satisfied (1500ms <= 2000ms)
    # t3: tolerating (2000ms < 5000ms <= 8000ms)
    # Apdex = (2 + 0.5) / 3 = 0.83
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 2.0)
    assert_equal 0.83, apdex
  end

  test "calculate should round to 2 decimal places" do
    # Create traces that result in 1/3 = 0.333...
    create_test_trace(@project, trace_id: "t1", duration_ms: 100)
    create_test_trace(@project, trace_id: "t2", duration_ms: 3000)
    create_test_trace(@project, trace_id: "t3", duration_ms: 3000)

    traces = @project.traces
    # Apdex = (1 + 0) / 3 = 0.333..., rounded to 0.33
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 0.33, apdex
  end

  test "calculate should handle edge case at threshold boundary" do
    # Exactly at threshold should be satisfied
    create_test_trace(@project, trace_id: "t1", duration_ms: 500)

    traces = @project.traces
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 1.0, apdex
  end

  test "calculate should handle edge case at 4x threshold boundary" do
    # Exactly at 4x threshold should be tolerating
    create_test_trace(@project, trace_id: "t1", duration_ms: 2000)

    traces = @project.traces
    # Apdex = (0 + 0.5) / 1 = 0.5
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 0.5, apdex
  end

  test "calculate should handle large number of traces" do
    # 70 satisfied
    70.times do |i|
      create_test_trace(@project, trace_id: "sat_#{i}", duration_ms: rand(100..500))
    end

    # 20 tolerating
    20.times do |i|
      create_test_trace(@project, trace_id: "tol_#{i}", duration_ms: rand(501..2000))
    end

    # 10 frustrated
    10.times do |i|
      create_test_trace(@project, trace_id: "fru_#{i}", duration_ms: rand(2001..5000))
    end

    traces = @project.traces
    # Apdex = (70 + 20/2) / 100 = 80 / 100 = 0.8
    apdex = ApdexCalculator.calculate(traces: traces, threshold: 0.5)
    assert_equal 0.8, apdex
  end
end
