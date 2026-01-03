require "test_helper"

class NotificationSenderTest < ActiveSupport::TestCase
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

  test "send! should mark notification as sent on success" do
    channel = @project.notification_channels.create!(
      name: "Email Team",
      kind: "email",
      config: { "addresses" => ["team@example.com"] },
      enabled: true
    )
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel,
      status: "pending"
    )

    sender = NotificationSender.new(notification: notification)
    sender.send!

    notification.reload
    assert_equal "sent", notification.status
    assert_not_nil notification.sent_at
  end

  test "send! should skip already sent notifications" do
    channel = @project.notification_channels.create!(
      name: "Email Team",
      kind: "email",
      config: { "addresses" => ["team@example.com"] },
      enabled: true
    )
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel,
      status: "sent",
      sent_at: 1.minute.ago
    )

    original_sent_at = notification.sent_at

    sender = NotificationSender.new(notification: notification)
    sender.send!

    notification.reload
    # sent_at should not change
    assert_equal original_sent_at.to_i, notification.sent_at.to_i
  end

  test "send! should mark notification as failed on error" do
    channel = @project.notification_channels.create!(
      name: "Webhook",
      kind: "webhook",
      config: { "url" => "https://invalid.example.com/webhook" },
      enabled: true
    )
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel,
      status: "pending"
    )

    # Mock HTTP to raise an error
    Net::HTTP.stub :new, ->(*_args) { raise StandardError, "Connection refused" } do
      sender = NotificationSender.new(notification: notification)
      sender.send!
    end

    notification.reload
    assert_equal "failed", notification.status
    assert_equal "Connection refused", notification.error_message
  end

  test "send! should increment channel success count on success" do
    channel = @project.notification_channels.create!(
      name: "Email Team",
      kind: "email",
      config: { "addresses" => ["team@example.com"] },
      enabled: true
    )
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel,
      status: "pending"
    )

    initial_count = channel.success_count

    sender = NotificationSender.new(notification: notification)
    sender.send!

    channel.reload
    assert_equal initial_count + 1, channel.success_count
  end

  test "send! should increment channel failure count on error" do
    channel = @project.notification_channels.create!(
      name: "Webhook",
      kind: "webhook",
      config: { "url" => "https://invalid.example.com/webhook" },
      enabled: true
    )
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel,
      status: "pending"
    )

    initial_count = channel.failure_count

    Net::HTTP.stub :new, ->(*_args) { raise StandardError, "Connection refused" } do
      sender = NotificationSender.new(notification: notification)
      sender.send!
    end

    channel.reload
    assert_equal initial_count + 1, channel.failure_count
  end

  test "send! should handle email notifications" do
    channel = @project.notification_channels.create!(
      name: "Email Team",
      kind: "email",
      config: { "addresses" => ["team@example.com", "admin@example.com"] },
      enabled: true
    )
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel,
      status: "pending"
    )

    sender = NotificationSender.new(notification: notification)
    sender.send!

    notification.reload
    assert_equal "sent", notification.status
  end

  test "send! should handle slack notifications with proper payload" do
    channel = @project.notification_channels.create!(
      name: "Slack #alerts",
      kind: "slack",
      config: { "webhook_url" => "https://hooks.slack.com/test", "channel" => "#alerts" },
      enabled: true
    )
    notification = AlertNotification.create!(
      alert: @alert,
      notification_channel: channel,
      status: "pending"
    )

    # Mock successful HTTP response
    mock_response = Minitest::Mock.new
    mock_response.expect :is_a?, true, [Net::HTTPSuccess]

    mock_http = Minitest::Mock.new
    mock_http.expect :use_ssl=, nil, [true]
    mock_http.expect :open_timeout=, nil, [10]
    mock_http.expect :read_timeout=, nil, [10]
    mock_http.expect :request, mock_response, [Net::HTTP::Post]

    Net::HTTP.stub :new, mock_http do
      sender = NotificationSender.new(notification: notification)
      sender.send!
    end

    notification.reload
    assert_equal "sent", notification.status
  end
end
