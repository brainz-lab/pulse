require "test_helper"

class NotificationChannelTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @channel = @project.notification_channels.create!(
      name: "Slack #alerts",
      kind: "slack",
      config: { "webhook_url" => "https://hooks.slack.com/test", "channel" => "#alerts" },
      enabled: true
    )
  end

  test "should be valid with valid attributes" do
    assert @channel.valid?
  end

  test "should require name" do
    channel = NotificationChannel.new(
      project: @project,
      kind: "email",
      config: {}
    )
    assert_not channel.valid?
    assert_includes channel.errors[:name], "can't be blank"
  end

  test "should require unique name per project" do
    duplicate = NotificationChannel.new(
      project: @project,
      name: @channel.name,
      kind: "email",
      config: {}
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name in different projects" do
    other_project = create_test_project(platform_project_id: SecureRandom.uuid)
    channel = NotificationChannel.new(
      project: other_project,
      name: @channel.name,
      kind: "email",
      config: {}
    )
    assert channel.valid?
  end

  test "should require kind" do
    channel = NotificationChannel.new(
      project: @project,
      name: "Test",
      config: {}
    )
    assert_not channel.valid?
    assert_includes channel.errors[:kind], "can't be blank"
  end

  test "should validate kind inclusion" do
    channel = NotificationChannel.new(
      project: @project,
      name: "Test",
      kind: "invalid",
      config: {}
    )
    assert_not channel.valid?
    assert_includes channel.errors[:kind], "is not included in the list"
  end

  test "should accept all valid kinds" do
    NotificationChannel::KINDS.each do |kind|
      channel = NotificationChannel.new(
        project: @project,
        name: "Test #{kind}",
        kind: kind,
        config: { "test" => "value" }
      )
      assert channel.valid?, "#{kind} should be a valid kind"
    end
  end

  test "should require config" do
    channel = NotificationChannel.new(
      project: @project,
      name: "Test",
      kind: "webhook"
    )
    assert_not channel.valid?
    assert_includes channel.errors[:config], "can't be blank"
  end

  test "scope enabled should filter enabled channels" do
    disabled_channel = @project.notification_channels.create!(
      name: "Disabled",
      kind: "email",
      config: { "addresses" => [ "test@example.com" ] },
      enabled: false
    )

    enabled = @project.notification_channels.enabled
    assert_includes enabled, @channel
    assert_not_includes enabled, disabled_channel
  end

  test "scope by_kind should filter by kind" do
    webhook_channel = @project.notification_channels.create!(
      name: "Webhook",
      kind: "webhook",
      config: { "url" => "https://example.com/webhook" },
      enabled: true
    )

    slack_channels = @project.notification_channels.by_kind("slack")
    assert_includes slack_channels, @channel
    assert_not_includes slack_channels, webhook_channel
  end

  test "webhook? should return true for webhook channels" do
    @channel.update!(kind: "webhook")
    assert @channel.webhook?
  end

  test "email? should return true for email channels" do
    @channel.update!(kind: "email")
    assert @channel.email?
  end

  test "slack? should return true for slack channels" do
    assert @channel.slack?
  end

  test "pagerduty? should return true for pagerduty channels" do
    @channel.update!(kind: "pagerduty")
    assert @channel.pagerduty?
  end

  test "record_success! should update counters and timestamp" do
    initial_count = @channel.success_count
    @channel.record_success!

    @channel.reload
    assert_equal initial_count + 1, @channel.success_count
    assert_not_nil @channel.last_used_at
  end

  test "record_failure! should update counters and timestamp" do
    initial_count = @channel.failure_count
    @channel.record_failure!

    @channel.reload
    assert_equal initial_count + 1, @channel.failure_count
    assert_not_nil @channel.last_used_at
  end

  test "webhook_url should return webhook URL from config" do
    @channel.update!(kind: "webhook", config: { "url" => "https://example.com/hook" })
    assert_equal "https://example.com/hook", @channel.webhook_url
  end

  test "webhook_headers should return headers from config" do
    headers = { "Authorization" => "Bearer token" }
    @channel.update!(kind: "webhook", config: { "url" => "test", "headers" => headers })
    assert_equal headers, @channel.webhook_headers
  end

  test "webhook_headers should return empty hash if not set" do
    @channel.update!(kind: "webhook", config: { "url" => "test" })
    assert_equal({}, @channel.webhook_headers)
  end

  test "email_addresses should return addresses from config" do
    addresses = [ "test@example.com", "admin@example.com" ]
    @channel.update!(kind: "email", config: { "addresses" => addresses })
    assert_equal addresses, @channel.email_addresses
  end

  test "email_addresses should return empty array if not set" do
    @channel.update!(kind: "email", config: {})
    assert_equal [], @channel.email_addresses
  end

  test "slack_webhook_url should return slack webhook URL from config" do
    webhook_url = "https://hooks.slack.com/services/TEST"
    @channel.update!(config: { "webhook_url" => webhook_url })
    assert_equal webhook_url, @channel.slack_webhook_url
  end

  test "slack_channel should return slack channel from config" do
    assert_equal "#alerts", @channel.slack_channel
  end

  test "pagerduty_integration_key should return integration key from config" do
    key = "abc123def456"
    @channel.update!(kind: "pagerduty", config: { "integration_key" => key })
    assert_equal key, @channel.pagerduty_integration_key
  end

  test "pagerduty_severity should return severity from config" do
    @channel.update!(kind: "pagerduty", config: { "integration_key" => "test", "severity" => "critical" })
    assert_equal "critical", @channel.pagerduty_severity
  end

  test "pagerduty_severity should default to error" do
    @channel.update!(kind: "pagerduty", config: { "integration_key" => "test" })
    assert_equal "error", @channel.pagerduty_severity
  end

  test "should belong to project" do
    assert_equal @project, @channel.project
  end

  test "should store config as JSONB" do
    config = {
      "url" => "https://example.com",
      "headers" => { "X-API-Key" => "secret" },
      "timeout" => 30
    }
    @channel.update!(config: config)

    @channel.reload
    assert_equal config, @channel.config
  end
end
