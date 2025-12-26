require "test_helper"

class Api::V1::TracesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project
    @api_key = "pls_test_#{SecureRandom.hex(16)}"
    @project.update!(settings: { "api_key" => @api_key })
  end

  def auth_headers
    { "Authorization" => "Bearer #{@api_key}" }
  end

  test "POST /api/v1/traces should create trace" do
    trace_data = {
      trace_id: SecureRandom.hex(16),
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      ended_at: (Time.current + 0.5).iso8601,
      request_method: "GET",
      request_path: "/users",
      status: 200
    }

    assert_difference "Trace.count", 1 do
      post "/api/v1/traces", params: trace_data, headers: auth_headers, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_includes json, "id"
    assert_includes json, "trace_id"
    assert_equal trace_data[:trace_id], json["trace_id"]
  end

  test "POST /api/v1/traces should create trace with spans" do
    trace_data = {
      trace_id: SecureRandom.hex(16),
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601,
      ended_at: (Time.current + 0.5).iso8601,
      spans: [
        {
          span_id: "span1",
          name: "SELECT users",
          kind: "db",
          started_at: Time.current.iso8601,
          ended_at: (Time.current + 0.1).iso8601,
          duration_ms: 100,
          data: { sql: "SELECT * FROM users" }
        }
      ]
    }

    assert_difference ["Trace.count", "Span.count"], 1 do
      post "/api/v1/traces", params: trace_data, headers: auth_headers, as: :json
    end

    assert_response :created
  end

  test "POST /api/v1/traces should require authentication" do
    trace_data = {
      trace_id: SecureRandom.hex(16),
      name: "GET /users",
      kind: "request",
      started_at: Time.current.iso8601
    }

    post "/api/v1/traces", params: trace_data, as: :json

    assert_response :unauthorized
  end

  test "POST /api/v1/traces/batch should create multiple traces" do
    traces_data = {
      traces: [
        {
          trace_id: "trace1",
          name: "GET /users",
          kind: "request",
          started_at: Time.current.iso8601
        },
        {
          trace_id: "trace2",
          name: "POST /posts",
          kind: "request",
          started_at: Time.current.iso8601
        }
      ]
    }

    assert_difference "Trace.count", 2 do
      post "/api/v1/traces/batch", params: traces_data, headers: auth_headers, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 2, json["processed"]
    assert_equal 2, json["results"].length
  end

  test "GET /api/v1/traces should list traces" do
    3.times do |i|
      create_test_trace(@project,
        trace_id: "trace#{i}",
        started_at: i.minutes.ago
      )
    end

    get "/api/v1/traces", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json, "traces"
    assert_equal 3, json["traces"].length
  end

  test "GET /api/v1/traces should filter by kind" do
    create_test_trace(@project, trace_id: "req1", kind: "request")
    create_test_trace(@project, trace_id: "job1", kind: "job")

    get "/api/v1/traces", params: { kind: "request" }, headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["traces"].length
    assert_equal "request", json["traces"][0]["kind"]
  end

  test "GET /api/v1/traces should filter by controller" do
    create_test_trace(@project, trace_id: "t1", controller: "UsersController")
    create_test_trace(@project, trace_id: "t2", controller: "PostsController")

    get "/api/v1/traces", params: { controller: "UsersController" }, headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["traces"].length
    assert_equal "UsersController", json["traces"][0]["controller"]
  end

  test "GET /api/v1/traces should filter slow traces" do
    create_test_trace(@project, trace_id: "fast", duration_ms: 100)
    create_test_trace(@project, trace_id: "slow", duration_ms: 2000)

    get "/api/v1/traces", params: { slow: 1000 }, headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["traces"].length
    assert json["traces"][0]["duration_ms"] > 1000
  end

  test "GET /api/v1/traces should filter error traces" do
    create_test_trace(@project, trace_id: "ok", error: false)
    create_test_trace(@project, trace_id: "err", error: true)

    get "/api/v1/traces", params: { errors: "true" }, headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["traces"].length
    assert json["traces"][0]["error"]
  end

  test "GET /api/v1/traces should filter by time range" do
    create_test_trace(@project, trace_id: "old", started_at: 2.hours.ago)
    create_test_trace(@project, trace_id: "new", started_at: 10.minutes.ago)

    get "/api/v1/traces",
      params: { since: 1.hour.ago.iso8601 },
      headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["traces"].length
  end

  test "GET /api/v1/traces should limit results" do
    5.times do |i|
      create_test_trace(@project, trace_id: "trace#{i}")
    end

    get "/api/v1/traces", params: { limit: 2 }, headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["traces"].length
  end

  test "GET /api/v1/traces/:id should show trace with spans" do
    trace = create_test_trace(@project,
      trace_id: "test123",
      ended_at: Time.current,
      duration_ms: 500
    )

    span = create_test_span(trace,
      span_id: "span1",
      kind: "db",
      duration_ms: 100
    )

    get "/api/v1/traces/#{trace.trace_id}", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json, "trace"
    assert_includes json, "spans"
    assert_equal trace.trace_id, json["trace"]["trace_id"]
    assert_equal 1, json["spans"].length
    assert_equal "span1", json["spans"][0][:id]
  end

  test "GET /api/v1/traces/:id should return 404 for non-existent trace" do
    get "/api/v1/traces/nonexistent", headers: auth_headers

    assert_response :not_found
  end

  test "GET /api/v1/traces/:id should not show traces from other projects" do
    other_project = create_test_project(platform_project_id: SecureRandom.uuid)
    other_trace = create_test_trace(other_project, trace_id: "other")

    get "/api/v1/traces/#{other_trace.trace_id}", headers: auth_headers

    assert_response :not_found
  end
end
