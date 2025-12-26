require "test_helper"

class AlertRuleTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @alert_rule = @project.alert_rules.create!(
      name: "High Error Rate",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      cooldown_minutes: 15,
      severity: "critical",
      enabled: true,
      status: "ok"
    )
  end

  test "should be valid with valid attributes" do
    assert @alert_rule.valid?
  end

  test "should require name" do
    rule = AlertRule.new(
      project: @project,
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0
    )
    assert_not rule.valid?
    assert_includes rule.errors[:name], "can't be blank"
  end

  test "should require metric_type" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      operator: "gt",
      threshold: 5.0
    )
    assert_not rule.valid?
    assert_includes rule.errors[:metric_type], "can't be blank"
  end

  test "should validate metric_type inclusion" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      metric_type: "invalid",
      operator: "gt",
      threshold: 5.0
    )
    assert_not rule.valid?
    assert_includes rule.errors[:metric_type], "is not included in the list"
  end

  test "should validate operator inclusion" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      metric_type: "error_rate",
      operator: "invalid",
      threshold: 5.0
    )
    assert_not rule.valid?
    assert_includes rule.errors[:operator], "is not included in the list"
  end

  test "should require threshold" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      metric_type: "error_rate",
      operator: "gt"
    )
    assert_not rule.valid?
    assert_includes rule.errors[:threshold], "can't be blank"
  end

  test "should validate threshold is numeric" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      metric_type: "error_rate",
      operator: "gt",
      threshold: "not a number"
    )
    assert_not rule.valid?
    assert_includes rule.errors[:threshold], "is not a number"
  end

  test "should validate window_minutes is positive" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      window_minutes: 0
    )
    assert_not rule.valid?
  end

  test "should require metric_name for custom metrics" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      metric_type: "custom",
      operator: "gt",
      threshold: 100
    )
    assert_not rule.valid?
    assert_includes rule.errors[:metric_name], "can't be blank"
  end

  test "should not require metric_name for non-custom metrics" do
    rule = AlertRule.new(
      project: @project,
      name: "Test",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      status: "ok"
    )
    assert rule.valid?
  end

  test "scope enabled should filter enabled rules" do
    disabled_rule = @project.alert_rules.create!(
      name: "Disabled",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      aggregation: "avg",
      window_minutes: 5,
      severity: "info",
      enabled: false,
      status: "ok"
    )

    enabled = @project.alert_rules.enabled
    assert_includes enabled, @alert_rule
    assert_not_includes enabled, disabled_rule
  end

  test "scope alerting should filter alerting rules" do
    @alert_rule.update!(status: "alerting")

    alerting = @project.alert_rules.alerting
    assert_includes alerting, @alert_rule
  end

  test "custom_metric? should return true for custom metrics" do
    rule = AlertRule.new(metric_type: "custom")
    assert rule.custom_metric?
  end

  test "custom_metric? should return false for non-custom metrics" do
    assert_not @alert_rule.custom_metric?
  end

  test "condition_met? should evaluate gt operator" do
    @alert_rule.update!(operator: "gt", threshold: 5.0)
    assert @alert_rule.condition_met?(6.0)
    assert_not @alert_rule.condition_met?(5.0)
    assert_not @alert_rule.condition_met?(4.0)
  end

  test "condition_met? should evaluate gte operator" do
    @alert_rule.update!(operator: "gte", threshold: 5.0)
    assert @alert_rule.condition_met?(6.0)
    assert @alert_rule.condition_met?(5.0)
    assert_not @alert_rule.condition_met?(4.0)
  end

  test "condition_met? should evaluate lt operator" do
    @alert_rule.update!(operator: "lt", threshold: 5.0)
    assert @alert_rule.condition_met?(4.0)
    assert_not @alert_rule.condition_met?(5.0)
    assert_not @alert_rule.condition_met?(6.0)
  end

  test "condition_met? should evaluate lte operator" do
    @alert_rule.update!(operator: "lte", threshold: 5.0)
    assert @alert_rule.condition_met?(4.0)
    assert @alert_rule.condition_met?(5.0)
    assert_not @alert_rule.condition_met?(6.0)
  end

  test "condition_met? should evaluate eq operator" do
    @alert_rule.update!(operator: "eq", threshold: 5.0)
    assert @alert_rule.condition_met?(5.0)
    assert_not @alert_rule.condition_met?(4.0)
    assert_not @alert_rule.condition_met?(6.0)
  end

  test "in_cooldown? should return false when never triggered" do
    assert_not @alert_rule.in_cooldown?
  end

  test "in_cooldown? should return true during cooldown period" do
    @alert_rule.update!(
      last_triggered_at: 5.minutes.ago,
      cooldown_minutes: 15
    )
    assert @alert_rule.in_cooldown?
  end

  test "in_cooldown? should return false after cooldown period" do
    @alert_rule.update!(
      last_triggered_at: 30.minutes.ago,
      cooldown_minutes: 15
    )
    assert_not @alert_rule.in_cooldown?
  end

  test "trigger! should create alert and update status" do
    alert = @alert_rule.trigger!(value: 10.5)

    assert_not_nil alert
    @alert_rule.reload
    assert_equal "alerting", @alert_rule.status
    assert_not_nil @alert_rule.last_triggered_at
  end

  test "trigger! should not trigger during cooldown" do
    @alert_rule.update!(
      last_triggered_at: 5.minutes.ago,
      cooldown_minutes: 15
    )

    alert = @alert_rule.trigger!(value: 10.5)

    assert_nil alert
  end

  test "trigger! should create alert with correct attributes" do
    alert = @alert_rule.trigger!(value: 10.5, endpoint: "/api/users", environment: "production")

    assert_equal @project, alert.project
    assert_equal "critical", alert.severity
    assert_equal "error_rate", alert.metric_type
    assert_equal "gt", alert.operator
    assert_equal 5.0, alert.threshold
    assert_equal 10.5, alert.value
    assert_equal "/api/users", alert.endpoint
    assert_equal "production", alert.environment
  end

  test "resolve! should update status and resolve alerts" do
    alert = @alert_rule.trigger!(value: 10.5)
    @alert_rule.reload

    @alert_rule.resolve!
    @alert_rule.reload

    assert_equal "ok", @alert_rule.status

    alert.reload
    assert_equal "resolved", alert.status
    assert_not_nil alert.resolved_at
  end

  test "resolve! should not do anything if not alerting" do
    initial_status = @alert_rule.status
    @alert_rule.resolve!

    @alert_rule.reload
    assert_equal initial_status, @alert_rule.status
  end

  test "human_condition should format condition readably" do
    @alert_rule.update!(operator: "gt", threshold: 5.0)
    assert_equal "Error rate > 5.0%", @alert_rule.human_condition
  end

  test "should belong to project" do
    assert_equal @project, @alert_rule.project
  end

  test "should have many alerts" do
    alert = @alert_rule.trigger!(value: 10.5)
    assert_includes @alert_rule.alerts, alert
  end

  test "should destroy associated alerts on destroy" do
    alert = @alert_rule.trigger!(value: 10.5)
    alert_id = alert.id

    @alert_rule.destroy

    assert_nil Alert.find_by(id: alert_id)
  end
end
