require "test_helper"

class Api::V1::SpansControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project
    @api_key = "pls_test_#{SecureRandom.hex(16)}"
    @project.update!(settings: { "api_key" => @api_key })
    @trace = create_test_trace(@project, trace_id: "test_trace_123")
  end

  def auth_headers
    { "Authorization" => "Bearer #{@api_key}" }
  end

  test "POST /api/v1/traces/:trace_id/spans should create span" do
    span_data = {
      span_id: "span_abc123",
      name: "SELECT users",
      kind: "db",
      started_at: Time.current.iso8601,
      duration_ms: 50,
      data: { sql: "SELECT * FROM users" }
    }

    assert_difference "Span.count", 1 do
      post "/api/v1/traces/#{@trace.trace_id}/spans",
        params: span_data,
        headers: auth_headers,
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "span_abc123", json["span_id"]
  end

  test "POST /api/v1/traces/:trace_id/spans should generate span_id if not provided" do
    span_data = {
      name: "HTTP Request",
      kind: "http",
      started_at: Time.current.iso8601
    }

    post "/api/v1/traces/#{@trace.trace_id}/spans",
      params: span_data,
      headers: auth_headers,
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_not_nil json["span_id"]
    assert_not_empty json["span_id"]
  end

  test "POST /api/v1/traces/:trace_id/spans should accept parent_span_id" do
    parent_span = create_test_span(@trace, span_id: "parent_span")

    span_data = {
      span_id: "child_span",
      parent_span_id: "parent_span",
      name: "Child Operation",
      kind: "custom",
      started_at: Time.current.iso8601
    }

    post "/api/v1/traces/#{@trace.trace_id}/spans",
      params: span_data,
      headers: auth_headers,
      as: :json

    assert_response :created
    span = @project.spans.find_by(span_id: "child_span")
    assert_equal "parent_span", span.parent_span_id
  end

  test "POST /api/v1/traces/:trace_id/spans should accept error info" do
    span_data = {
      span_id: "error_span",
      name: "Failed Operation",
      kind: "custom",
      started_at: Time.current.iso8601,
      error: true,
      error_class: "StandardError",
      error_message: "Something went wrong"
    }

    post "/api/v1/traces/#{@trace.trace_id}/spans",
      params: span_data,
      headers: auth_headers,
      as: :json

    assert_response :created
    span = @project.spans.find_by(span_id: "error_span")
    assert span.error
    assert_equal "StandardError", span.error_class
    assert_equal "Something went wrong", span.error_message
  end

  test "POST /api/v1/traces/:trace_id/spans should accept data as JSON" do
    span_data = {
      span_id: "data_span",
      name: "DB Query",
      kind: "db",
      started_at: Time.current.iso8601,
      data: {
        sql: "SELECT * FROM users WHERE id = $1",
        table: "users",
        operation: "SELECT",
        rows_affected: 1
      }
    }

    post "/api/v1/traces/#{@trace.trace_id}/spans",
      params: span_data,
      headers: auth_headers,
      as: :json

    assert_response :created
    span = @project.spans.find_by(span_id: "data_span")
    assert_equal "SELECT * FROM users WHERE id = $1", span.data["sql"]
    assert_equal "users", span.data["table"]
    assert_equal 1, span.data["rows_affected"]
  end

  test "POST /api/v1/traces/:trace_id/spans should default kind to custom" do
    span_data = {
      span_id: "no_kind_span",
      name: "Some Operation",
      started_at: Time.current.iso8601
    }

    post "/api/v1/traces/#{@trace.trace_id}/spans",
      params: span_data,
      headers: auth_headers,
      as: :json

    assert_response :created
    span = @project.spans.find_by(span_id: "no_kind_span")
    assert_equal "custom", span.kind
  end

  test "POST /api/v1/traces/:trace_id/spans should return 404 for non-existent trace" do
    span_data = {
      name: "Orphan Span",
      kind: "custom",
      started_at: Time.current.iso8601
    }

    post "/api/v1/traces/nonexistent_trace/spans",
      params: span_data,
      headers: auth_headers,
      as: :json

    assert_response :not_found
  end

  test "POST /api/v1/traces/:trace_id/spans should require authentication" do
    span_data = {
      name: "Unauthenticated Span",
      kind: "custom",
      started_at: Time.current.iso8601
    }

    post "/api/v1/traces/#{@trace.trace_id}/spans",
      params: span_data,
      as: :json

    assert_response :unauthorized
  end

  test "POST /api/v1/traces/:trace_id/spans should update trace metrics" do
    span_data = {
      span_id: "db_span",
      name: "SELECT",
      kind: "db",
      started_at: Time.current.iso8601,
      duration_ms: 100
    }

    post "/api/v1/traces/#{@trace.trace_id}/spans",
      params: span_data,
      headers: auth_headers,
      as: :json

    assert_response :created
    @trace.reload
    assert_equal 1, @trace.span_count
    assert_equal 100.0, @trace.db_duration_ms
  end
end
