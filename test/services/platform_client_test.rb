require "test_helper"

class PlatformClientTest < ActiveSupport::TestCase
  test "validate_key should return invalid for blank key" do
    result = PlatformClient.validate_key(nil)
    assert_equal false, result[:valid]

    result = PlatformClient.validate_key("")
    assert_equal false, result[:valid]
  end

  test "validate_key should return valid response from platform" do
    mock_response = Minitest::Mock.new
    mock_response.expect :code, "200"
    mock_response.expect :body, {
      valid: true,
      project_id: "proj_123",
      organization_id: "org_456",
      project_name: "My Project",
      product: "pulse",
      key_type: "ingest",
      plan: "pro",
      limits: { traces_per_day: 100000 },
      environment: "production",
      features: { pulse: true },
      quota_remaining: { traces: 50000 }
    }.to_json

    mock_http = Minitest::Mock.new
    mock_http.expect :use_ssl=, nil, [false]
    mock_http.expect :open_timeout=, nil, [5]
    mock_http.expect :read_timeout=, nil, [5]
    mock_http.expect :request, mock_response, [Net::HTTP::Post]

    Net::HTTP.stub :new, mock_http do
      result = PlatformClient.validate_key("pls_ingest_abc123")

      assert result[:valid]
      assert_equal "proj_123", result[:project_id]
      assert_equal "My Project", result[:project_name]
      assert_equal "pulse", result[:product]
      assert_equal "pro", result[:plan]
      assert result[:features][:pulse]
    end
  end

  test "validate_key should return invalid for failed validation" do
    mock_response = Minitest::Mock.new
    mock_response.expect :code, "200"
    mock_response.expect :body, { valid: false }.to_json

    mock_http = Minitest::Mock.new
    mock_http.expect :use_ssl=, nil, [false]
    mock_http.expect :open_timeout=, nil, [5]
    mock_http.expect :read_timeout=, nil, [5]
    mock_http.expect :request, mock_response, [Net::HTTP::Post]

    # In test environment, should return invalid (no dev fallback)
    Rails.stub :env, ActiveSupport::StringInquirer.new("test") do
      Net::HTTP.stub :new, mock_http do
        result = PlatformClient.validate_key("invalid_key")
        assert_equal false, result[:valid]
      end
    end
  end

  test "validate_key should use dev fallback in development when platform unavailable" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      Net::HTTP.stub :new, ->(*_args) { raise StandardError, "Connection refused" } do
        result = PlatformClient.validate_key("dev_test_key")

        assert result[:valid]
        assert_match /^dev_/, result[:project_id]
        assert_equal "Development Project", result[:project_name]
        assert_equal "development", result[:environment]
        assert result[:features][:pulse]
      end
    end
  end

  test "validate_key should not use dev fallback in production" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("production") do
      Net::HTTP.stub :new, ->(*_args) { raise StandardError, "Connection refused" } do
        result = PlatformClient.validate_key("prod_test_key")

        assert_equal false, result[:valid]
      end
    end
  end

  test "validate_key should handle non-200 responses" do
    mock_response = Minitest::Mock.new
    mock_response.expect :code, "500"

    mock_http = Minitest::Mock.new
    mock_http.expect :use_ssl=, nil, [false]
    mock_http.expect :open_timeout=, nil, [5]
    mock_http.expect :read_timeout=, nil, [5]
    mock_http.expect :request, mock_response, [Net::HTTP::Post]

    Rails.stub :env, ActiveSupport::StringInquirer.new("test") do
      Net::HTTP.stub :new, mock_http do
        result = PlatformClient.validate_key("test_key")
        assert_equal false, result[:valid]
      end
    end
  end

  test "dev_fallback should generate consistent project_id for same key" do
    result1 = PlatformClient.dev_fallback("my_test_key")
    result2 = PlatformClient.dev_fallback("my_test_key")

    assert_equal result1[:project_id], result2[:project_id]
  end

  test "dev_fallback should generate different project_id for different keys" do
    result1 = PlatformClient.dev_fallback("key_one")
    result2 = PlatformClient.dev_fallback("key_two")

    assert_not_equal result1[:project_id], result2[:project_id]
  end

  test "track_usage should not track zero or negative counts" do
    thread_started = false

    Thread.stub :new, ->(&_block) { thread_started = true } do
      PlatformClient.track_usage(project_id: "proj_123", product: "pulse", metric: "traces", count: 0)
      assert_not thread_started

      PlatformClient.track_usage(project_id: "proj_123", product: "pulse", metric: "traces", count: -1)
      assert_not thread_started
    end
  end

  test "track_usage should start background thread for positive counts" do
    thread_started = false

    Thread.stub :new, ->(&_block) { thread_started = true } do
      PlatformClient.track_usage(project_id: "proj_123", product: "pulse", metric: "traces", count: 10)
      assert thread_started
    end
  end
end
