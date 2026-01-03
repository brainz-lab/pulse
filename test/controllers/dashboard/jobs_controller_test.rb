require "test_helper"

class Dashboard::JobsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/jobs should list jobs" do
    @project.traces.create!(
      trace_id: SecureRandom.hex(16),
      name: "ProcessDataJob",
      kind: "job",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 2,
      duration_ms: 2000
    )

    get "/dashboard/jobs", env: session_params

    assert_response :success
  end

  test "GET /dashboard/jobs should handle empty data" do
    get "/dashboard/jobs", env: session_params

    assert_response :success
  end

  test "GET /dashboard/jobs/:id should show job details" do
    trace = @project.traces.create!(
      trace_id: "job_123",
      name: "SendEmailJob",
      kind: "job",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 1,
      duration_ms: 1000,
      queue: "default"
    )

    get "/dashboard/jobs/#{trace.trace_id}", env: session_params

    assert_response :success
  end
end
