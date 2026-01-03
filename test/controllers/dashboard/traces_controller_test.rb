require "test_helper"

class Dashboard::TracesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/traces should redirect to requests" do
    get "/dashboard/traces", env: session_params

    assert_response :redirect
    assert_redirected_to dashboard_requests_path
  end

  test "GET /dashboard/traces should preserve query params on redirect" do
    get "/dashboard/traces", params: { slow: true }, env: session_params

    assert_response :redirect
  end

  test "GET /dashboard/traces/:id should show trace details" do
    trace = create_test_trace(@project,
      trace_id: "trace_detail_123",
      name: "GET /api/users",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.5,
      duration_ms: 500
    )

    get "/dashboard/traces/#{trace.trace_id}", env: session_params

    assert_response :success
  end

  test "GET /dashboard/traces/:id should show trace with spans" do
    trace = create_test_trace(@project,
      trace_id: "trace_with_spans",
      name: "GET /users",
      kind: "request"
    )
    create_test_span(trace, name: "DB Query", kind: "db")
    create_test_span(trace, name: "Render View", kind: "render")

    get "/dashboard/traces/#{trace.trace_id}", env: session_params

    assert_response :success
  end

  test "GET /dashboard/traces/:id should return 404 for non-existent trace" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/dashboard/traces/nonexistent", env: session_params
    end
  end
end
