require "test_helper"

class AlertRuleChannelTest < ActiveSupport::TestCase
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
    @notification_channel = @project.notification_channels.create!(
      name: "Slack #alerts",
      kind: "slack",
      config: { "webhook_url" => "https://hooks.slack.com/test", "channel" => "#alerts" },
      enabled: true
    )
    @alert_rule_channel = AlertRuleChannel.create!(
      alert_rule: @alert_rule,
      notification_channel: @notification_channel
    )
  end

  test "should be valid with valid attributes" do
    assert @alert_rule_channel.valid?
  end

  test "should belong to alert_rule" do
    assert_equal @alert_rule, @alert_rule_channel.alert_rule
  end

  test "should belong to notification_channel" do
    assert_equal @notification_channel, @alert_rule_channel.notification_channel
  end

  test "should validate uniqueness of alert_rule_id scoped to notification_channel_id" do
    duplicate = AlertRuleChannel.new(
      alert_rule: @alert_rule,
      notification_channel: @notification_channel
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:alert_rule_id], "has already been taken"
  end

  test "should allow same alert_rule with different notification_channel" do
    other_channel = @project.notification_channels.create!(
      name: "Email Team",
      kind: "email",
      config: { "addresses" => ["team@example.com"] },
      enabled: true
    )

    rule_channel = AlertRuleChannel.new(
      alert_rule: @alert_rule,
      notification_channel: other_channel
    )
    assert rule_channel.valid?
  end

  test "should allow same notification_channel with different alert_rule" do
    other_rule = @project.alert_rules.create!(
      name: "Low Throughput",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      enabled: true,
      status: "ok"
    )

    rule_channel = AlertRuleChannel.new(
      alert_rule: other_rule,
      notification_channel: @notification_channel
    )
    assert rule_channel.valid?
  end

  test "alert_rule should have notification_channels through alert_rule_channels" do
    assert_includes @alert_rule.notification_channels, @notification_channel
  end

  test "notification_channel should have alert_rules through alert_rule_channels" do
    assert_includes @notification_channel.alert_rules, @alert_rule
  end

  test "destroying alert_rule should destroy associated alert_rule_channels" do
    channel_id = @alert_rule_channel.id
    @alert_rule.destroy

    assert_nil AlertRuleChannel.find_by(id: channel_id)
  end

  test "destroying notification_channel should destroy associated alert_rule_channels" do
    channel_id = @alert_rule_channel.id
    @notification_channel.destroy

    assert_nil AlertRuleChannel.find_by(id: channel_id)
  end
end
