require "test_helper"

class Dashboard::AlertsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
    @alert_rule = @project.alert_rules.create!(
      name: "Test Alert Rule",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "critical",
      status: "ok"
    )
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/alerts should list alerts" do
    @alert_rule.alerts.create!(
      project: @project,
      severity: "critical",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      value: 10.5,
      message: "Error rate too high",
      triggered_at: Time.current,
      status: "firing"
    )

    get "/dashboard/alerts", env: session_params

    assert_response :success
  end

  test "GET /dashboard/alerts should handle empty alerts" do
    get "/dashboard/alerts", env: session_params

    assert_response :success
  end

  test "GET /dashboard/alerts/:id should show alert details" do
    alert = @alert_rule.alerts.create!(
      project: @project,
      severity: "critical",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      value: 10.5,
      message: "Error rate too high",
      triggered_at: Time.current,
      status: "firing"
    )

    get "/dashboard/alerts/#{alert.id}", env: session_params

    assert_response :success
  end
end
