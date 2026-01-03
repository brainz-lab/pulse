require "test_helper"

class Dashboard::MetricsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/metrics should list metrics" do
    create_test_metric(@project, name: "response_time")
    create_test_metric(@project, name: "error_count")

    get "/dashboard/metrics", env: session_params

    assert_response :success
  end

  test "GET /dashboard/metrics should handle empty metrics" do
    get "/dashboard/metrics", env: session_params

    assert_response :success
  end

  test "GET /dashboard/metrics/:id should show metric details" do
    metric = create_test_metric(@project, name: "test_metric")
    metric.record!(100)
    metric.record!(200)

    get "/dashboard/metrics/#{metric.id}", env: session_params

    assert_response :success
  end

  test "GET /dashboard/metrics/:id should accept since parameter" do
    metric = create_test_metric(@project, name: "time_metric")

    get "/dashboard/metrics/#{metric.id}",
      params: { since: "24h" },
      env: session_params

    assert_response :success
  end
end
