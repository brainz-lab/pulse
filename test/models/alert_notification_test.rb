require "test_helper"

class AlertNotificationTest < ActiveSupport::TestCase
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
    @notification_channel = @project.notification_channels.create!(
      name: "Slack #alerts",
      kind: "slack",
      config: { "webhook_url" => "https://hooks.slack.com/test", "channel" => "#alerts" },
      enabled: true
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
    @notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: @notification_channel,
      status: "pending"
    )
  end

  test "should be valid with valid attributes" do
    assert @notification.valid?
  end

  test "should require valid status" do
    notification = AlertNotification.new(
      alert: @alert,
      notification_channel: @notification_channel,
      status: nil
    )
    # Status may have a default value, so just check validation works
    notification.status = nil
    assert_not notification.valid?
  end

  test "should validate status inclusion" do
    notification = AlertNotification.new(
      alert: @alert,
      notification_channel: @notification_channel,
      status: "invalid"
    )
    assert_not notification.valid?
    assert_includes notification.errors[:status], "is not included in the list"
  end

  test "should accept all valid statuses" do
    AlertNotification::STATUSES.each do |status|
      notification = AlertNotification.new(
        alert: @alert,
        notification_channel: @notification_channel,
        status: status
      )
      assert notification.valid?, "#{status} should be a valid status"
    end
  end

  # Scopes
  test "scope pending should filter pending notifications" do
    # Create a different channel for the sent notification
    other_channel = @project.notification_channels.create!(
      name: "Email",
      kind: "email",
      config: { "addresses" => ["test@example.com"] },
      enabled: true
    )
    sent_notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: other_channel,
      status: "sent",
      sent_at: Time.current
    )

    pending = AlertNotification.pending
    assert_includes pending, @notification
    assert_not_includes pending, sent_notification
  end

  test "scope sent should filter sent notifications" do
    # Update the existing notification to sent instead of creating duplicate
    @notification.update!(status: "sent", sent_at: Time.current)

    # Create a new pending notification with different channel
    other_channel = @project.notification_channels.create!(
      name: "Email",
      kind: "email",
      config: { "addresses" => ["test@example.com"] },
      enabled: true
    )
    pending_notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: other_channel,
      status: "pending"
    )

    sent = AlertNotification.sent
    assert_includes sent, @notification
    assert_not_includes sent, pending_notification
  end

  test "scope failed should filter failed notifications" do
    # Create a different channel for the failed notification
    other_channel = @project.notification_channels.create!(
      name: "Email",
      kind: "email",
      config: { "addresses" => ["test@example.com"] },
      enabled: true
    )
    failed_notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: other_channel,
      status: "failed",
      error_message: "Connection timeout"
    )

    failed = AlertNotification.failed
    assert_includes failed, failed_notification
    assert_not_includes failed, @notification
  end

  # Predicates
  test "pending? should return true for pending notifications" do
    assert @notification.pending?
  end

  test "pending? should return false for sent notifications" do
    @notification.update!(status: "sent", sent_at: Time.current)
    assert_not @notification.pending?
  end

  test "sent? should return true for sent notifications" do
    @notification.update!(status: "sent", sent_at: Time.current)
    assert @notification.sent?
  end

  test "sent? should return false for pending notifications" do
    assert_not @notification.sent?
  end

  test "failed? should return true for failed notifications" do
    @notification.update!(status: "failed", error_message: "Error")
    assert @notification.failed?
  end

  test "failed? should return false for pending notifications" do
    assert_not @notification.failed?
  end

  # mark_sent!
  test "mark_sent! should update status to sent" do
    @notification.mark_sent!
    @notification.reload

    assert_equal "sent", @notification.status
  end

  test "mark_sent! should set sent_at timestamp" do
    freeze_time do
      @notification.mark_sent!
      @notification.reload

      assert_equal Time.current, @notification.sent_at
    end
  end

  test "mark_sent! should record success on notification channel" do
    initial_count = @notification_channel.success_count

    @notification.mark_sent!
    @notification_channel.reload

    assert_equal initial_count + 1, @notification_channel.success_count
  end

  # mark_failed!
  test "mark_failed! should update status to failed" do
    @notification.mark_failed!("Connection refused")
    @notification.reload

    assert_equal "failed", @notification.status
  end

  test "mark_failed! should set error message" do
    error_message = "Connection refused"
    @notification.mark_failed!(error_message)
    @notification.reload

    assert_equal error_message, @notification.error_message
  end

  test "mark_failed! should record failure on notification channel" do
    initial_count = @notification_channel.failure_count

    @notification.mark_failed!("Error")
    @notification_channel.reload

    assert_equal initial_count + 1, @notification_channel.failure_count
  end

  # Associations
  test "should belong to alert" do
    assert_equal @alert, @notification.alert
  end

  test "should belong to notification_channel" do
    assert_equal @notification_channel, @notification.notification_channel
  end
end
