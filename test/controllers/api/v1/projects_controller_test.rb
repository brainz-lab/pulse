require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @master_key = "test_master_key_#{SecureRandom.hex(16)}"
    ENV["PULSE_MASTER_KEY"] = @master_key
  end

  def teardown
    ENV.delete("PULSE_MASTER_KEY")
  end

  def master_headers
    { "X-Master-Key" => @master_key }
  end

  # POST /api/v1/projects/provision
  test "POST /api/v1/projects/provision should create new project" do
    project_data = {
      name: "My Test App",
      environment: "development"
    }

    assert_difference "Project.count", 1 do
      post "/api/v1/projects/provision",
        params: project_data,
        headers: master_headers,
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json, "id"
    assert_includes json, "name"
    assert_includes json, "api_key"
    assert_includes json, "platform_project_id"
    assert_equal "My Test App", json["name"]
    assert json["api_key"].start_with?("pls_")
  end

  test "POST /api/v1/projects/provision should return existing project with same name" do
    existing = Project.create!(
      platform_project_id: SecureRandom.uuid,
      name: "Existing App"
    )

    assert_no_difference "Project.count" do
      post "/api/v1/projects/provision",
        params: { name: "Existing App" },
        headers: master_headers,
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal existing.id, json["id"]
  end

  test "POST /api/v1/projects/provision should require name" do
    post "/api/v1/projects/provision",
      params: { name: "" },
      headers: master_headers,
      as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Name is required", json["error"]
  end

  test "POST /api/v1/projects/provision should require master key" do
    post "/api/v1/projects/provision",
      params: { name: "Test App" },
      as: :json

    assert_response :unauthorized
  end

  test "POST /api/v1/projects/provision should reject invalid master key" do
    post "/api/v1/projects/provision",
      params: { name: "Test App" },
      headers: { "X-Master-Key" => "wrong_key" },
      as: :json

    assert_response :unauthorized
  end

  test "POST /api/v1/projects/provision should use default environment" do
    post "/api/v1/projects/provision",
      params: { name: "Default Env App" },
      headers: master_headers,
      as: :json

    assert_response :success
    project = Project.find_by(name: "Default Env App")
    assert_equal "development", project.environment
  end

  test "POST /api/v1/projects/provision should accept custom environment" do
    post "/api/v1/projects/provision",
      params: { name: "Production App", environment: "production" },
      headers: master_headers,
      as: :json

    assert_response :success
    project = Project.find_by(name: "Production App")
    assert_equal "production", project.environment
  end

  # GET /api/v1/projects/lookup
  test "GET /api/v1/projects/lookup should find project by name" do
    project = Project.create!(
      platform_project_id: SecureRandom.uuid,
      name: "Lookup Test",
      settings: { "api_key" => "pls_test_key_123" }
    )

    get "/api/v1/projects/lookup",
      params: { name: "Lookup Test" },
      headers: master_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal project.id, json["id"]
    assert_equal "Lookup Test", json["name"]
    assert_equal "pls_test_key_123", json["api_key"]
  end

  test "GET /api/v1/projects/lookup should return 404 for non-existent project" do
    get "/api/v1/projects/lookup",
      params: { name: "Non Existent" },
      headers: master_headers

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Project not found", json["error"]
  end

  test "GET /api/v1/projects/lookup should require master key" do
    get "/api/v1/projects/lookup",
      params: { name: "Test" }

    assert_response :unauthorized
  end

  test "GET /api/v1/projects/lookup should handle project without api_key in settings" do
    project = Project.create!(
      platform_project_id: SecureRandom.uuid,
      name: "No Key Project"
    )

    get "/api/v1/projects/lookup",
      params: { name: "No Key Project" },
      headers: master_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal project.id, json["id"]
    # api_key may be nil if not set
  end
end
