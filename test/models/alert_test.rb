require "test_helper"

class AlertTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @alert_rule = @project.alert_rules.create!(
      name: "High Error Rate",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "critical",
      status: "ok"
    )
    @alert = @alert_rule.alerts.create!(
      project: @project,
      severity: "critical",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      value: 10.5,
      message: "Error rate is 10.5% (threshold: 5.0%)",
      triggered_at: Time.current,
      status: "firing"
    )
  end

  test "should be valid with valid attributes" do
    assert @alert.valid?
  end

  test "should require status" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      severity: "warning",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: Time.current
    )
    assert_not alert.valid?
    assert_includes alert.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      severity: "warning",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: Time.current,
      status: "invalid"
    )
    assert_not alert.valid?
    assert_includes alert.errors[:status], "is not included in the list"
  end

  test "should require severity" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: Time.current,
      status: "firing"
    )
    assert_not alert.valid?
    assert_includes alert.errors[:severity], "can't be blank"
  end

  test "should require metric_type" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      severity: "warning",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: Time.current,
      status: "firing"
    )
    assert_not alert.valid?
    assert_includes alert.errors[:metric_type], "can't be blank"
  end

  test "should require operator" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      severity: "warning",
      metric_type: "throughput",
      threshold: 10,
      value: 5,
      triggered_at: Time.current,
      status: "firing"
    )
    assert_not alert.valid?
    assert_includes alert.errors[:operator], "can't be blank"
  end

  test "should require threshold" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      severity: "warning",
      metric_type: "throughput",
      operator: "lt",
      value: 5,
      triggered_at: Time.current,
      status: "firing"
    )
    assert_not alert.valid?
    assert_includes alert.errors[:threshold], "can't be blank"
  end

  test "should require value" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      severity: "warning",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      triggered_at: Time.current,
      status: "firing"
    )
    assert_not alert.valid?
    assert_includes alert.errors[:value], "can't be blank"
  end

  test "should require triggered_at" do
    alert = Alert.new(
      project: @project,
      alert_rule: @alert_rule,
      severity: "warning",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      status: "firing"
    )
    assert_not alert.valid?
    assert_includes alert.errors[:triggered_at], "can't be blank"
  end

  test "scope firing should filter firing alerts" do
    resolved_alert = @alert_rule.alerts.create!(
      project: @project,
      severity: "warning",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      value: 6.0,
      triggered_at: 1.hour.ago,
      resolved_at: 30.minutes.ago,
      status: "resolved"
    )

    firing = @project.alerts.firing
    assert_includes firing, @alert
    assert_not_includes firing, resolved_alert
  end

  test "scope resolved should filter resolved alerts" do
    resolved_alert = @alert_rule.alerts.create!(
      project: @project,
      severity: "warning",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      value: 6.0,
      triggered_at: 1.hour.ago,
      resolved_at: 30.minutes.ago,
      status: "resolved"
    )

    resolved = @project.alerts.resolved
    assert_includes resolved, resolved_alert
    assert_not_includes resolved, @alert
  end

  test "scope recent should order by triggered_at desc" do
    alert1 = @alert_rule.alerts.create!(
      project: @project,
      severity: "info",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: 2.hours.ago,
      status: "firing"
    )

    alert2 = @alert_rule.alerts.create!(
      project: @project,
      severity: "info",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: 30.minutes.ago,
      status: "firing"
    )

    recent = @project.alerts.recent.to_a
    assert_equal alert2.id, recent[0].id
    assert_equal @alert.id, recent[1].id
    assert_equal alert1.id, recent[2].id
  end

  test "scope critical should filter critical alerts" do
    warning_alert = @alert_rule.alerts.create!(
      project: @project,
      severity: "warning",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: Time.current,
      status: "firing"
    )

    critical = @project.alerts.critical
    assert_includes critical, @alert
    assert_not_includes critical, warning_alert
  end

  test "scope warning should filter warning alerts" do
    warning_alert = @alert_rule.alerts.create!(
      project: @project,
      severity: "warning",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      value: 5,
      triggered_at: Time.current,
      status: "firing"
    )

    warnings = @project.alerts.warning
    assert_includes warnings, warning_alert
    assert_not_includes warnings, @alert
  end

  test "firing? should return true for firing alerts" do
    assert @alert.firing?
  end

  test "firing? should return false for resolved alerts" do
    @alert.update!(status: "resolved", resolved_at: Time.current)
    assert_not @alert.firing?
  end

  test "resolved? should return true for resolved alerts" do
    @alert.update!(status: "resolved", resolved_at: Time.current)
    assert @alert.resolved?
  end

  test "resolved? should return false for firing alerts" do
    assert_not @alert.resolved?
  end

  test "duration should return nil for firing alerts" do
    assert_nil @alert.duration
  end

  test "duration should calculate duration for resolved alerts" do
    triggered = Time.current
    resolved = triggered + 10.minutes

    @alert.update!(
      triggered_at: triggered,
      resolved_at: resolved,
      status: "resolved"
    )

    assert_in_delta 600, @alert.duration, 1
  end

  test "duration_text should return ongoing for firing alerts" do
    assert_equal "ongoing", @alert.duration_text
  end

  test "duration_text should format seconds" do
    @alert.update!(
      triggered_at: Time.current - 45.seconds,
      resolved_at: Time.current,
      status: "resolved"
    )
    assert_equal "45s", @alert.duration_text
  end

  test "duration_text should format minutes" do
    @alert.update!(
      triggered_at: Time.current - 5.minutes,
      resolved_at: Time.current,
      status: "resolved"
    )
    assert_equal "5m", @alert.duration_text
  end

  test "duration_text should format hours and minutes" do
    @alert.update!(
      triggered_at: Time.current - 2.hours - 15.minutes,
      resolved_at: Time.current,
      status: "resolved"
    )
    assert_equal "2h 15m", @alert.duration_text
  end

  test "severity_color should return correct colors" do
    @alert.update!(severity: "critical")
    assert_equal "#DC2626", @alert.severity_color

    @alert.update!(severity: "warning")
    assert_equal "#F59E0B", @alert.severity_color

    @alert.update!(severity: "info")
    assert_equal "#6B7280", @alert.severity_color
  end

  test "severity_badge_class should return correct CSS classes" do
    @alert.update!(severity: "critical")
    assert_equal "bg-red-100 text-red-800", @alert.severity_badge_class

    @alert.update!(severity: "warning")
    assert_equal "bg-amber-100 text-amber-800", @alert.severity_badge_class

    @alert.update!(severity: "info")
    assert_equal "bg-gray-100 text-gray-800", @alert.severity_badge_class
  end

  test "should belong to project" do
    assert_equal @project, @alert.project
  end

  test "should belong to alert_rule" do
    assert_equal @alert_rule, @alert.alert_rule
  end
end
