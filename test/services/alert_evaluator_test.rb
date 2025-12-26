require "test_helper"

class AlertEvaluatorTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project(apdex_t: 0.5)
    @evaluator = AlertEvaluator.new(project: @project)
  end

  test "evaluate_rule! should update last_checked_at" do
    rule = @project.alert_rules.create!(
      name: "High Error Rate",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "critical",
      enabled: true,
      status: "ok"
    )

    @evaluator.evaluate_rule!(rule)

    rule.reload
    assert_not_nil rule.last_checked_at
  end

  test "evaluate_rule! should trigger alert when condition met" do
    rule = @project.alert_rules.create!(
      name: "High Error Rate",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "critical",
      enabled: true,
      status: "ok"
    )

    # Create traces with > 5% error rate
    7.times { create_test_trace(@project, duration_ms: 100, error: false, started_at: 2.minutes.ago) }
    3.times { create_test_trace(@project, duration_ms: 100, error: true, started_at: 2.minutes.ago) }
    # Error rate = 30%

    assert_difference "Alert.count", 1 do
      @evaluator.evaluate_rule!(rule)
    end

    rule.reload
    assert_equal "alerting", rule.status
  end

  test "evaluate_rule! should resolve alert when condition not met" do
    rule = @project.alert_rules.create!(
      name: "High Error Rate",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "critical",
      enabled: true,
      status: "alerting",
      last_triggered_at: 10.minutes.ago
    )

    alert = rule.alerts.create!(
      project: @project,
      severity: "critical",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      value: 10.0,
      triggered_at: 10.minutes.ago,
      status: "firing"
    )

    # Create traces with low error rate
    19.times { create_test_trace(@project, duration_ms: 100, error: false, started_at: 2.minutes.ago) }
    1.times { create_test_trace(@project, duration_ms: 100, error: true, started_at: 2.minutes.ago) }
    # Error rate = 5%

    @evaluator.evaluate_rule!(rule)

    rule.reload
    alert.reload

    assert_equal "ok", rule.status
    assert_equal "resolved", alert.status
    assert_not_nil alert.resolved_at
  end

  test "evaluate_rule! should evaluate apdex metric" do
    rule = @project.alert_rules.create!(
      name: "Low Apdex",
      metric_type: "apdex",
      operator: "lt",
      threshold: 0.8,
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    # Create traces with poor Apdex (many slow/frustrated)
    2.times { create_test_trace(@project, duration_ms: 200, started_at: 2.minutes.ago) }  # Satisfied
    1.times { create_test_trace(@project, duration_ms: 1000, started_at: 2.minutes.ago) }  # Tolerating
    7.times { create_test_trace(@project, duration_ms: 3000, started_at: 2.minutes.ago) }  # Frustrated
    # Apdex = (2 + 0.5) / 10 = 0.25 < 0.8

    assert_difference "Alert.count", 1 do
      @evaluator.evaluate_rule!(rule)
    end

    rule.reload
    assert_equal "alerting", rule.status
  end

  test "evaluate_rule! should evaluate throughput metric" do
    rule = @project.alert_rules.create!(
      name: "Low Throughput",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10.0,  # 10 requests per minute
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    # Create only 2 traces in 5 minute window
    # Throughput = 2 / 5 = 0.4 rpm < 10
    2.times do |i|
      create_test_trace(@project,
        trace_id: "throughput_#{i}",
        duration_ms: 100,
        started_at: 2.minutes.ago
      )
    end

    assert_difference "Alert.count", 1 do
      @evaluator.evaluate_rule!(rule)
    end
  end

  test "evaluate_rule! should evaluate response_time with avg aggregation" do
    rule = @project.alert_rules.create!(
      name: "High Response Time",
      metric_type: "response_time",
      operator: "gt",
      threshold: 500,  # 500ms
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    # Create traces with average > 500ms
    create_test_trace(@project, duration_ms: 600, started_at: 2.minutes.ago)
    create_test_trace(@project, duration_ms: 800, started_at: 2.minutes.ago)
    create_test_trace(@project, duration_ms: 700, started_at: 2.minutes.ago)
    # Avg = 700ms > 500ms

    assert_difference "Alert.count", 1 do
      @evaluator.evaluate_rule!(rule)
    end
  end

  test "evaluate_rule! should evaluate p95 metric" do
    rule = @project.alert_rules.create!(
      name: "High P95",
      metric_type: "p95",
      operator: "gt",
      threshold: 1000,
      aggregation: "p95",
      window_minutes: 5,
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    # Create 100 traces with varying durations
    95.times { |i| create_test_trace(@project, trace_id: "fast_#{i}", duration_ms: 100, started_at: 2.minutes.ago) }
    5.times { |i| create_test_trace(@project, trace_id: "slow_#{i}", duration_ms: 2000, started_at: 2.minutes.ago) }
    # P95 should be around 2000ms > 1000ms

    assert_difference "Alert.count", 1 do
      @evaluator.evaluate_rule!(rule)
    end
  end

  test "evaluate_rule! should filter by endpoint if specified" do
    rule = @project.alert_rules.create!(
      name: "Endpoint Specific",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 10.0,
      aggregation: "avg",
      window_minutes: 5,
      endpoint: "/api/users",
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    # High error rate on /api/users
    create_test_trace(@project, request_path: "/api/users", error: true, started_at: 2.minutes.ago)
    create_test_trace(@project, request_path: "/api/users", error: true, started_at: 2.minutes.ago)

    # Low error rate on other endpoints
    create_test_trace(@project, request_path: "/api/posts", error: false, started_at: 2.minutes.ago)
    create_test_trace(@project, request_path: "/api/posts", error: false, started_at: 2.minutes.ago)

    assert_difference "Alert.count", 1 do
      @evaluator.evaluate_rule!(rule)
    end

    alert = Alert.last
    assert_equal "/api/users", alert.endpoint
  end

  test "evaluate_rule! should filter by environment if specified" do
    rule = @project.alert_rules.create!(
      name: "Production Only",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      environment: "production",
      severity: "critical",
      enabled: true,
      status: "ok"
    )

    # High error rate in production
    3.times { create_test_trace(@project, environment: "production", error: true, duration_ms: 100, started_at: 2.minutes.ago) }
    2.times { create_test_trace(@project, environment: "production", error: false, duration_ms: 100, started_at: 2.minutes.ago) }

    # Low error rate in staging (should not trigger)
    10.times { create_test_trace(@project, environment: "staging", error: false, duration_ms: 100, started_at: 2.minutes.ago) }

    assert_difference "Alert.count", 1 do
      @evaluator.evaluate_rule!(rule)
    end

    alert = Alert.last
    assert_equal "production", alert.environment
  end

  test "evaluate_all! should evaluate all enabled rules" do
    rule1 = @project.alert_rules.create!(
      name: "Rule 1",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 50.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "critical",
      enabled: true,
      status: "ok"
    )

    rule2 = @project.alert_rules.create!(
      name: "Rule 2",
      metric_type: "throughput",
      operator: "lt",
      threshold: 1.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    # Create conditions that trigger both rules
    5.times { create_test_trace(@project, error: true, started_at: 2.minutes.ago) }
    5.times { create_test_trace(@project, error: false, started_at: 2.minutes.ago) }

    @evaluator.evaluate_all!

    rule1.reload
    rule2.reload

    assert_not_nil rule1.last_checked_at
    assert_not_nil rule2.last_checked_at
  end

  test "evaluate_all! should skip disabled rules" do
    disabled_rule = @project.alert_rules.create!(
      name: "Disabled",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 0.0,  # Would always trigger
      aggregation: "avg",
      window_minutes: 5,
      severity: "info",
      enabled: false,
      status: "ok"
    )

    create_test_trace(@project, error: true, started_at: 2.minutes.ago)

    assert_no_difference "Alert.count" do
      @evaluator.evaluate_all!
    end

    disabled_rule.reload
    assert_nil disabled_rule.last_checked_at
  end

  test "evaluate_rule! should not trigger if no data in window" do
    rule = @project.alert_rules.create!(
      name: "No Data",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    # Create traces outside the window
    create_test_trace(@project, error: true, started_at: 1.hour.ago)

    assert_no_difference "Alert.count" do
      @evaluator.evaluate_rule!(rule)
    end

    rule.reload
    assert_equal "ok", rule.status
  end
end
