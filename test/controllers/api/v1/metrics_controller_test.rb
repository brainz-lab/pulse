require "test_helper"

class Api::V1::MetricsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project
    @api_key = "pls_test_#{SecureRandom.hex(16)}"
    @project.update!(settings: { "api_key" => @api_key })
  end

  def auth_headers
    { "Authorization" => "Bearer #{@api_key}" }
  end

  # POST /api/v1/metrics
  test "POST /api/v1/metrics should create metric and record value" do
    metric_data = {
      name: "response_time",
      value: 150.5,
      kind: "gauge"
    }

    assert_difference "Metric.count", 1 do
      post "/api/v1/metrics", params: metric_data, headers: auth_headers, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_includes json, "metric_id"

    metric = Metric.find(json["metric_id"])
    assert_equal "response_time", metric.name
    assert_equal "gauge", metric.kind
    assert_equal 1, metric.points.count
    assert_equal 150.5, metric.points.last.value
  end

  test "POST /api/v1/metrics should use existing metric with same name" do
    existing_metric = create_test_metric(@project, name: "existing_metric")

    metric_data = {
      name: "existing_metric",
      value: 200.0
    }

    assert_no_difference "Metric.count" do
      post "/api/v1/metrics", params: metric_data, headers: auth_headers, as: :json
    end

    assert_response :created
    assert_equal 1, existing_metric.points.count
  end

  test "POST /api/v1/metrics should accept tags" do
    metric_data = {
      name: "request_count",
      value: 1,
      kind: "counter",
      tags: { "endpoint" => "/api/users", "method" => "GET" }
    }

    post "/api/v1/metrics", params: metric_data, headers: auth_headers, as: :json

    assert_response :created
    metric = @project.metrics.find_by(name: "request_count")
    point = metric.points.last
    assert_equal "/api/users", point.tags["endpoint"]
    assert_equal "GET", point.tags["method"]
  end

  test "POST /api/v1/metrics should accept custom timestamp" do
    custom_time = 1.hour.ago.iso8601
    metric_data = {
      name: "test_metric",
      value: 100,
      timestamp: custom_time
    }

    post "/api/v1/metrics", params: metric_data, headers: auth_headers, as: :json

    assert_response :created
    metric = @project.metrics.find_by(name: "test_metric")
    assert_in_delta 1.hour.ago.to_i, metric.points.last.timestamp.to_i, 5
  end

  test "POST /api/v1/metrics should require authentication" do
    post "/api/v1/metrics", params: { name: "test", value: 1 }, as: :json

    assert_response :unauthorized
  end

  # POST /api/v1/metrics/batch
  test "POST /api/v1/metrics/batch should create multiple metrics" do
    batch_data = {
      metrics: [
        { name: "metric_1", value: 100 },
        { name: "metric_2", value: 200 },
        { name: "metric_3", value: 300 }
      ]
    }

    assert_difference "Metric.count", 3 do
      post "/api/v1/metrics/batch", params: batch_data, headers: auth_headers, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 3, json["processed"]
  end

  test "POST /api/v1/metrics/batch should add points to existing metrics" do
    create_test_metric(@project, name: "existing")

    batch_data = {
      metrics: [
        { name: "existing", value: 100 },
        { name: "existing", value: 200 }
      ]
    }

    assert_no_difference "Metric.count" do
      post "/api/v1/metrics/batch", params: batch_data, headers: auth_headers, as: :json
    end

    assert_response :created
    metric = @project.metrics.find_by(name: "existing")
    assert_equal 2, metric.points.count
  end

  # GET /api/v1/metrics
  test "GET /api/v1/metrics should list metrics" do
    create_test_metric(@project, name: "metric_a")
    create_test_metric(@project, name: "metric_b")

    get "/api/v1/metrics", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json, "metrics"
    assert_equal 2, json["metrics"].length
  end

  test "GET /api/v1/metrics should only show project metrics" do
    other_project = create_test_project(platform_project_id: SecureRandom.uuid)
    create_test_metric(@project, name: "my_metric")
    create_test_metric(other_project, name: "other_metric")

    get "/api/v1/metrics", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["metrics"].length
    assert_equal "my_metric", json["metrics"][0]["name"]
  end

  # GET /api/v1/metrics/:name/stats
  test "GET /api/v1/metrics/:name/stats should return metric statistics" do
    metric = create_test_metric(@project, name: "test_stat_metric")
    metric.record!(100)
    metric.record!(200)
    metric.record!(300)

    get "/api/v1/metrics/#{metric.name}/stats", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json, "stats"
  end

  test "GET /api/v1/metrics/:name/stats should accept since parameter" do
    metric = create_test_metric(@project, name: "time_range_metric")
    metric.record!(100, timestamp: 2.hours.ago)
    metric.record!(200, timestamp: 30.minutes.ago)

    get "/api/v1/metrics/#{metric.name}/stats",
      params: { since: 1.hour.ago.iso8601 },
      headers: auth_headers

    assert_response :success
  end

  test "GET /api/v1/metrics/:name/stats should accept granularity parameter" do
    metric = create_test_metric(@project, name: "granularity_metric")
    metric.record!(100)

    get "/api/v1/metrics/#{metric.name}/stats",
      params: { granularity: "hour" },
      headers: auth_headers

    assert_response :success
  end

  test "GET /api/v1/metrics/:name/stats should return 404 for non-existent metric" do
    get "/api/v1/metrics/nonexistent/stats", headers: auth_headers

    assert_response :not_found
  end

  # GET /api/v1/overview
  test "GET /api/v1/overview should return project overview" do
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    get "/api/v1/overview", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json, "apdex"
    assert_includes json, "throughput"
    assert_includes json, "rpm"
    assert_includes json, "error_rate"
  end

  test "GET /api/v1/overview should accept since parameter" do
    create_test_trace(@project,
      kind: "request",
      started_at: 2.hours.ago,
      ended_at: 2.hours.ago + 0.1,
      duration_ms: 100
    )
    create_test_trace(@project,
      kind: "request",
      started_at: 30.minutes.ago,
      ended_at: 30.minutes.ago + 0.1,
      duration_ms: 100
    )

    get "/api/v1/overview",
      params: { since: 1.hour.ago.iso8601 },
      headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["throughput"]
  end
end
