require "test_helper"

class Api::V1::DeploysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = create_test_project
    @api_key = "pls_test_#{SecureRandom.hex(16)}"
    @project.update!(settings: { "api_key" => @api_key })
  end

  def auth_headers
    { "Authorization" => "Bearer #{@api_key}" }
  end

  test "POST /api/v1/deploys should create deploy" do
    deploy_data = {
      version: "1.2.3",
      commit_sha: "abc123def456",
      deployed_by: "ci-bot",
      environment: "production",
      description: "Fix login bug"
    }

    assert_difference "Deploy.count", 1 do
      post "/api/v1/deploys", params: deploy_data, headers: auth_headers, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "1.2.3", json["deploy"]["version"]
    assert_equal "abc123def456", json["deploy"]["commit_sha"]
    assert_equal "ci-bot", json["deploy"]["deployed_by"]
    assert_equal "production", json["deploy"]["environment"]
  end

  test "POST /api/v1/deploys should use project environment as default" do
    @project.update!(environment: "staging")

    post "/api/v1/deploys",
      params: { version: "2.0.0" },
      headers: auth_headers, as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "staging", json["deploy"]["environment"]
  end

  test "POST /api/v1/deploys should set deployed_at to current time by default" do
    post "/api/v1/deploys",
      params: { version: "1.0.0" },
      headers: auth_headers, as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_not_nil json["deploy"]["deployed_at"]
  end

  test "POST /api/v1/deploys should accept custom deployed_at" do
    custom_time = 1.hour.ago.iso8601

    post "/api/v1/deploys",
      params: { version: "1.0.0", deployed_at: custom_time },
      headers: auth_headers, as: :json

    assert_response :created
  end

  test "POST /api/v1/deploys should require authentication" do
    post "/api/v1/deploys",
      params: { version: "1.0.0" },
      as: :json

    assert_response :unauthorized
  end

  test "POST /api/v1/deploys should require version" do
    post "/api/v1/deploys",
      params: { commit_sha: "abc123" },
      headers: auth_headers, as: :json

    assert_response :unprocessable_entity
  end

  test "GET /api/v1/deploys should list deploys" do
    3.times do |i|
      @project.deploys.create!(version: "1.0.#{i}", deployed_at: i.hours.ago)
    end

    get "/api/v1/deploys", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 3, json["deploys"].length
    # Ordered by deployed_at desc
    assert_equal "1.0.0", json["deploys"].first["version"]
  end

  test "GET /api/v1/deploys should filter by since" do
    @project.deploys.create!(version: "1.0.0", deployed_at: 3.hours.ago)
    @project.deploys.create!(version: "2.0.0", deployed_at: 30.minutes.ago)

    get "/api/v1/deploys",
      params: { since: 1.hour.ago.iso8601 },
      headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["deploys"].length
    assert_equal "2.0.0", json["deploys"].first["version"]
  end

  test "GET /api/v1/deploys should limit results" do
    5.times do |i|
      @project.deploys.create!(version: "1.0.#{i}", deployed_at: i.hours.ago)
    end

    get "/api/v1/deploys",
      params: { limit: 2 },
      headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["deploys"].length
  end

  test "GET /api/v1/deploys should require authentication" do
    get "/api/v1/deploys"

    assert_response :unauthorized
  end
end
