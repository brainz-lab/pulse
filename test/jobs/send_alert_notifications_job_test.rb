require "test_helper"

class SendAlertNotificationsJobTest < ActiveSupport::TestCase
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
      enabled: true,
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
  end

  test "perform should send pending notifications" do
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: @notification_channel,
      status: "pending"
    )

    sender_mock = Minitest::Mock.new
    sender_mock.expect :send!, nil

    NotificationSender.stub :new, ->(**args) {
      assert_equal notification, args[:notification]
      sender_mock
    } do
      SendAlertNotificationsJob.new.perform(@alert.id)
    end

    sender_mock.verify
  end

  test "perform should skip already sent notifications" do
    sent_notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: @notification_channel,
      status: "sent",
      sent_at: Time.current
    )

    sender_called = false
    NotificationSender.stub :new, ->(**_args) {
      sender_called = true
      Minitest::Mock.new
    } do
      SendAlertNotificationsJob.new.perform(@alert.id)
    end

    assert_not sender_called, "NotificationSender should not be called for sent notifications"
  end

  test "perform should handle non-existent alert gracefully" do
    assert_nothing_raised do
      SendAlertNotificationsJob.new.perform("non-existent-id")
    end
  end

  test "perform should handle nil alert_id gracefully" do
    assert_nothing_raised do
      SendAlertNotificationsJob.new.perform(nil)
    end
  end

  test "perform should process multiple pending notifications" do
    channel2 = @project.notification_channels.create!(
      name: "Email Team",
      kind: "email",
      config: { "addresses" => ["team@example.com"] },
      enabled: true
    )

    notification1 = AlertNotification.create!(
      alert: @alert,
      notification_channel: @notification_channel,
      status: "pending"
    )
    notification2 = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel2,
      status: "pending"
    )

    notifications_processed = []
    NotificationSender.stub :new, ->(**args) {
      notifications_processed << args[:notification]
      mock = Minitest::Mock.new
      mock.expect :send!, nil
      mock
    } do
      SendAlertNotificationsJob.new.perform(@alert.id)
    end

    assert_equal 2, notifications_processed.length
    assert_includes notifications_processed, notification1
    assert_includes notifications_processed, notification2
  end

  test "perform should be assigned to default queue" do
    job = SendAlertNotificationsJob.new
    assert_equal "default", job.queue_name
  end
end
