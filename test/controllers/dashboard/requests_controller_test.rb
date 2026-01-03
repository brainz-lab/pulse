require "test_helper"

class Dashboard::RequestsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/requests should list requests" do
    3.times do |i|
      create_test_trace(@project,
        name: "GET /users/#{i}",
        kind: "request",
        started_at: i.minutes.ago
      )
    end

    get "/dashboard/requests", env: session_params

    assert_response :success
  end

  test "GET /dashboard/requests should filter slow requests" do
    create_test_trace(@project,
      name: "Fast",
      kind: "request",
      duration_ms: 100
    )
    create_test_trace(@project,
      name: "Slow",
      kind: "request",
      duration_ms: 2000
    )

    get "/dashboard/requests", params: { slow: true, threshold: 500 }, env: session_params

    assert_response :success
  end

  test "GET /dashboard/requests should filter error requests" do
    create_test_trace(@project,
      name: "Success",
      kind: "request",
      error: false
    )
    create_test_trace(@project,
      name: "Error",
      kind: "request",
      error: true
    )

    get "/dashboard/requests", params: { errors: true }, env: session_params

    assert_response :success
  end

  test "GET /dashboard/requests should paginate results" do
    30.times do |i|
      create_test_trace(@project,
        trace_id: "trace_#{i}",
        kind: "request"
      )
    end

    get "/dashboard/requests", env: session_params

    assert_response :success
  end

  test "GET /dashboard/requests/:id should show request details" do
    trace = create_test_trace(@project,
      trace_id: "request_123",
      name: "GET /users",
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.5,
      duration_ms: 500
    )

    get "/dashboard/requests/#{trace.trace_id}", env: session_params

    assert_response :success
  end

  test "GET /dashboard/requests/:id should return 404 for non-existent request" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/dashboard/requests/nonexistent", env: session_params
    end
  end
end
