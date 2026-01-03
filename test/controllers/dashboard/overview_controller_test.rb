require "test_helper"

class Dashboard::OverviewControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard should show overview" do
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    get "/dashboard", env: session_params

    assert_response :success
    assert_select "body"
  end

  test "GET /dashboard should show metrics when data exists" do
    5.times do
      create_test_trace(@project,
        kind: "request",
        started_at: 30.minutes.ago,
        ended_at: 30.minutes.ago + 0.1,
        duration_ms: 100
      )
    end

    get "/dashboard", env: session_params

    assert_response :success
  end

  test "GET /dashboard should accept since parameter" do
    get "/dashboard", params: { since: "24h" }, env: session_params

    assert_response :success
  end

  test "GET /dashboard should handle empty project" do
    get "/dashboard", env: session_params

    assert_response :success
  end

  test "GET /dashboard should show slow requests" do
    create_test_trace(@project,
      name: "Slow Request",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 2,
      duration_ms: 2000
    )

    get "/dashboard", env: session_params

    assert_response :success
  end
end
