require "test_helper"

class Dashboard::SlosControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project(platform_project_id: "pls_test_slo_project")
  end

  def session_params
    { "rack.session" => { platform_project_id: @project.platform_project_id } }
  end

  def create_slo(attrs = {})
    @project.service_level_objectives.create!({
      name: "P95 Latency SLO",
      target_metric: "p95",
      operator: "lte",
      threshold: 500.0,
      window_days: 30
    }.merge(attrs))
  end

  test "GET /dashboard/slos should list SLOs" do
    create_slo
    get "/dashboard/slos", env: session_params
    assert_response :success
  end

  test "GET /dashboard/slos should show empty state" do
    get "/dashboard/slos", env: session_params
    assert_response :success
  end

  test "GET /dashboard/slos/:id should show SLO detail" do
    slo = create_slo
    get "/dashboard/slos/#{slo.id}", env: session_params
    assert_response :success
  end

  test "GET /dashboard/slos/new should show new form" do
    get "/dashboard/slos/new", env: session_params
    assert_response :success
  end

  test "POST /dashboard/slos should create SLO" do
    slo_params = {
      service_level_objective: {
        name: "Error Rate SLO",
        target_metric: "error_rate",
        operator: "lte",
        threshold: 1.0,
        window_days: 30
      }
    }

    assert_difference "@project.service_level_objectives.count", 1 do
      post "/dashboard/slos", params: slo_params, env: session_params
    end

    assert_response :redirect
    slo = @project.service_level_objectives.last
    assert_redirected_to dashboard_slo_path(slo)
    assert_equal "Error Rate SLO", slo.name
  end

  test "POST /dashboard/slos should handle validation errors" do
    slo_params = {
      service_level_objective: {
        name: "",
        target_metric: "error_rate",
        operator: "lte",
        threshold: 1.0
      }
    }

    assert_no_difference "@project.service_level_objectives.count" do
      post "/dashboard/slos", params: slo_params, env: session_params
    end

    assert_response :unprocessable_entity
  end

  test "DELETE /dashboard/slos/:id should delete SLO" do
    slo = create_slo

    assert_difference "@project.service_level_objectives.count", -1 do
      delete "/dashboard/slos/#{slo.id}", env: session_params
    end

    assert_response :redirect
    assert_redirected_to dashboard_slos_path
  end

  test "index recalculates stale SLOs" do
    slo = create_slo(last_calculated_at: 10.minutes.ago)
    # Create some traces so calculator has data
    5.times { create_test_trace(@project, duration_ms: 100.0, kind: "request", started_at: 1.minute.ago) }

    get "/dashboard/slos", env: session_params
    assert_response :success

    slo.reload
    assert slo.last_calculated_at > 1.minute.ago
  end

  test "show recalculates SLO" do
    slo = create_slo(last_calculated_at: nil)
    get "/dashboard/slos/#{slo.id}", env: session_params
    assert_response :success

    slo.reload
    assert_not_nil slo.last_calculated_at
  end
end
