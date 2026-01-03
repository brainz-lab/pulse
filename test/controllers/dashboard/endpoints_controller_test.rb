require "test_helper"

class Dashboard::EndpointsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/endpoints should list endpoints" do
    create_test_trace(@project,
      name: "GET /api/users",
      kind: "request",
      started_at: 30.minutes.ago,
      duration_ms: 100
    )
    create_test_trace(@project,
      name: "POST /api/posts",
      kind: "request",
      started_at: 30.minutes.ago,
      duration_ms: 200
    )

    get "/dashboard/endpoints", env: session_params

    assert_response :success
  end

  test "GET /dashboard/endpoints should accept since parameter" do
    get "/dashboard/endpoints", params: { since: "24h" }, env: session_params

    assert_response :success
  end

  test "GET /dashboard/endpoints should handle empty data" do
    get "/dashboard/endpoints", env: session_params

    assert_response :success
  end
end
