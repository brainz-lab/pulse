require "test_helper"

class Dashboard::NotificationChannelsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/notification_channels should list channels" do
    @project.notification_channels.create!(
      name: "Slack #alerts",
      kind: "slack",
      config: { "webhook_url" => "https://hooks.slack.com/test" },
      enabled: true
    )

    get "/dashboard/notification_channels", env: session_params

    assert_response :success
  end

  test "GET /dashboard/notification_channels/new should show form" do
    get "/dashboard/notification_channels/new", env: session_params

    assert_response :success
  end

  test "POST /dashboard/notification_channels should create channel" do
    channel_params = {
      notification_channel: {
        name: "New Webhook",
        kind: "webhook",
        config: { "url" => "https://example.com/webhook" },
        enabled: true
      }
    }

    assert_difference "@project.notification_channels.count", 1 do
      post "/dashboard/notification_channels",
        params: channel_params,
        env: session_params
    end

    assert_response :redirect
  end

  test "GET /dashboard/notification_channels/:id should show channel" do
    channel = @project.notification_channels.create!(
      name: "Email Alerts",
      kind: "email",
      config: { "addresses" => ["team@example.com"] },
      enabled: true
    )

    get "/dashboard/notification_channels/#{channel.id}", env: session_params

    assert_response :success
  end

  test "DELETE /dashboard/notification_channels/:id should delete channel" do
    channel = @project.notification_channels.create!(
      name: "To Delete",
      kind: "webhook",
      config: { "url" => "https://example.com" },
      enabled: true
    )

    assert_difference "@project.notification_channels.count", -1 do
      delete "/dashboard/notification_channels/#{channel.id}", env: session_params
    end

    assert_response :redirect
  end
end
