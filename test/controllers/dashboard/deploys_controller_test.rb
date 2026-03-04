require "test_helper"

class Dashboard::DeploysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  test "GET /dashboard/deploys should list deploys" do
    3.times do |i|
      @project.deploys.create!(version: "1.0.#{i}", deployed_at: i.hours.ago)
    end

    get "/dashboard/deploys", env: session_params

    assert_response :success
  end

  test "GET /dashboard/deploys should render empty state" do
    get "/dashboard/deploys", env: session_params

    assert_response :success
  end

  test "GET /dashboard/deploys should show impact badges" do
    deploy = @project.deploys.create!(version: "1.0.0", deployed_at: 2.hours.ago)

    # Create traces before and after deploy
    5.times do
      create_test_trace(@project,
        kind: "request",
        started_at: deploy.deployed_at - 30.minutes,
        duration_ms: 100
      )
    end
    5.times do
      create_test_trace(@project,
        kind: "request",
        started_at: deploy.deployed_at + 30.minutes,
        duration_ms: 100
      )
    end

    get "/dashboard/deploys", env: session_params

    assert_response :success
  end

  test "GET /dashboard/deploys/:id should show deploy details" do
    deploy = @project.deploys.create!(
      version: "2.0.0",
      commit_sha: "abc123",
      deployed_by: "dev",
      environment: "production",
      deployed_at: 1.hour.ago
    )

    get "/dashboard/deploys/#{deploy.id}", env: session_params

    assert_response :success
  end

  test "GET /dashboard/deploys/:id should show impact with traces" do
    deploy = @project.deploys.create!(version: "1.5.0", deployed_at: 2.hours.ago)

    # Traces before deploy (fast)
    5.times do
      create_test_trace(@project,
        kind: "request",
        started_at: deploy.deployed_at - 30.minutes,
        duration_ms: 50
      )
    end

    # Traces after deploy (slow - degraded)
    5.times do
      create_test_trace(@project,
        kind: "request",
        started_at: deploy.deployed_at + 30.minutes,
        duration_ms: 500
      )
    end

    get "/dashboard/deploys/#{deploy.id}", env: session_params

    assert_response :success
  end

  test "GET /dashboard/deploys/:id should handle no trace data" do
    deploy = @project.deploys.create!(version: "1.0.0", deployed_at: 1.hour.ago)

    get "/dashboard/deploys/#{deploy.id}", env: session_params

    assert_response :success
  end
end
