require "test_helper"

class Dashboard::AlertRulesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/alert_rules should list alert rules" do
    @project.alert_rules.create!(
      name: "High Error Rate",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "critical",
      status: "ok"
    )

    get "/dashboard/alert_rules", env: session_params

    assert_response :success
  end

  test "GET /dashboard/alert_rules/new should show new form" do
    get "/dashboard/alert_rules/new", env: session_params

    assert_response :success
  end

  test "GET /dashboard/alert_rules/:id should show alert rule" do
    alert_rule = @project.alert_rules.create!(
      name: "Test Rule",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      status: "ok"
    )

    get "/dashboard/alert_rules/#{alert_rule.id}", env: session_params

    assert_response :success
  end

  test "POST /dashboard/alert_rules should create alert rule" do
    alert_rule_params = {
      alert_rule: {
        name: "New Alert",
        metric_type: "error_rate",
        operator: "gt",
        threshold: 5.0,
        aggregation: "avg",
        window_minutes: 5,
        cooldown_minutes: 60,
        severity: "critical"
      }
    }

    assert_difference "@project.alert_rules.count", 1 do
      post "/dashboard/alert_rules",
        params: alert_rule_params,
        env: session_params
    end

    assert_response :redirect
    assert_redirected_to dashboard_alert_rules_path
  end

  test "POST /dashboard/alert_rules should handle validation errors" do
    alert_rule_params = {
      alert_rule: {
        name: "",  # invalid - blank name
        metric_type: "error_rate",
        operator: "gt",
        threshold: 5.0
      }
    }

    assert_no_difference "@project.alert_rules.count" do
      post "/dashboard/alert_rules",
        params: alert_rule_params,
        env: session_params
    end

    assert_response :unprocessable_entity
  end

  test "PATCH /dashboard/alert_rules/:id should update alert rule" do
    alert_rule = @project.alert_rules.create!(
      name: "Original Name",
      metric_type: "error_rate",
      operator: "gt",
      threshold: 5.0,
      aggregation: "avg",
      window_minutes: 5,
      severity: "warning",
      status: "ok"
    )

    patch "/dashboard/alert_rules/#{alert_rule.id}",
      params: { alert_rule: { name: "Updated Name" } },
      env: session_params

    assert_response :redirect
    alert_rule.reload
    assert_equal "Updated Name", alert_rule.name
  end

  test "DELETE /dashboard/alert_rules/:id should delete alert rule" do
    alert_rule = @project.alert_rules.create!(
      name: "To Delete",
      metric_type: "throughput",
      operator: "lt",
      threshold: 10,
      aggregation: "avg",
      window_minutes: 5,
      severity: "info",
      status: "ok"
    )

    assert_difference "@project.alert_rules.count", -1 do
      delete "/dashboard/alert_rules/#{alert_rule.id}", env: session_params
    end

    assert_response :redirect
    assert_redirected_to dashboard_alert_rules_path
  end
end
