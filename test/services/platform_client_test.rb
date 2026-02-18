require "test_helper"

class PlatformClientTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "validate_key returns invalid for blank key" do
    result = PlatformClient.validate_key(nil)
    assert_not result.valid?
    assert_equal "Key required", result.error

    result = PlatformClient.validate_key("")
    assert_not result.valid?
    assert_equal "Key required", result.error
  end

  test "validate_key returns valid ValidationResult from platform" do
    response = build_http_response(Net::HTTPOK, {
      valid: true,
      project_id: "proj_123",
      project_slug: "my-project",
      organization_id: "org_456",
      organization_slug: "my-org",
      environment: "production",
      plan: "pro",
      scopes: [ "pulse" ],
      features: { pulse: true }
    })

    stub_http_request(response) do
      result = PlatformClient.validate_key("sk_live_test123")

      assert result.valid?
      assert_equal "proj_123", result.project_id
      assert_equal "my-project", result.project_slug
      assert_equal "org_456", result.organization_id
      assert_equal "my-org", result.organization_slug
      assert_equal "production", result.environment
      assert_equal "pro", result.plan
      assert_includes result.scopes, "pulse"
    end
  end

  test "validate_key returns invalid for unauthorized response" do
    response = build_http_response(Net::HTTPUnauthorized, { error: "Invalid API key" })

    stub_http_request(response) do
      result = PlatformClient.validate_key("sk_live_invalid")
      assert_not result.valid?
      assert_equal "Invalid API key", result.error
    end
  end

  test "validate_key returns invalid for server errors" do
    response = build_http_response(Net::HTTPInternalServerError, { error: "Internal server error" })

    stub_http_request(response) do
      result = PlatformClient.validate_key("sk_live_test")
      assert_not result.valid?
    end
  end

  test "validate_key handles timeouts gracefully" do
    mock_http = Minitest::Mock.new
    mock_http.expect :use_ssl=, nil, [ Object ]
    mock_http.expect :open_timeout=, nil, [ 5 ]
    mock_http.expect :read_timeout=, nil, [ 5 ]
    mock_http.expect :request, nil do |_req|
      raise Net::OpenTimeout, "execution expired"
    end

    Net::HTTP.stub :new, mock_http do
      result = PlatformClient.validate_key_uncached("sk_live_timeout")
      assert_not result.valid?
      assert_equal "Platform timeout", result.error
    end
  end

  test "validate_key handles connection errors gracefully" do
    Net::HTTP.stub :new, ->(*_args) { raise StandardError, "Connection refused" } do
      result = PlatformClient.validate_key_uncached("sk_live_error")
      assert_not result.valid?
      assert_equal "Platform error", result.error
    end
  end

  test "validate_key caches valid results" do
    response = build_http_response(Net::HTTPOK, {
      valid: true,
      project_id: "proj_cached",
      project_slug: "cached"
    })

    call_count = 0

    Net::HTTP.stub :new, ->(*_args) {
      call_count += 1
      mock = Minitest::Mock.new
      mock.expect :use_ssl=, nil, [ Object ]
      mock.expect :open_timeout=, nil, [ 5 ]
      mock.expect :read_timeout=, nil, [ 5 ]
      mock.expect :request, response, [ Net::HTTP::Post ]
      mock
    } do
      result1 = PlatformClient.validate_key("sk_live_cached_key")
      result2 = PlatformClient.validate_key("sk_live_cached_key")

      assert result1.valid?
      assert result2.valid?
      assert_equal 1, call_count, "Expected only one HTTP call due to caching"
    end
  end

  test "track_usage does not track zero or negative counts" do
    thread_started = false

    Thread.stub :new, ->(&_block) { thread_started = true } do
      PlatformClient.track_usage(project_id: "proj_123", product: "pulse", metric: "traces", count: 0)
      assert_not thread_started

      PlatformClient.track_usage(project_id: "proj_123", product: "pulse", metric: "traces", count: -1)
      assert_not thread_started
    end
  end

  test "track_usage starts background thread for positive counts" do
    thread_started = false

    Thread.stub :new, ->(&_block) { thread_started = true } do
      PlatformClient.track_usage(project_id: "proj_123", product: "pulse", metric: "traces", count: 10)
      assert thread_started
    end
  end

  private

  def build_http_response(klass, body)
    response = klass.new("1.1", klass::VALUE rescue "200", "")
    response.instance_variable_set(:@body, body.to_json)
    response.instance_variable_set(:@read, true)
    response
  end

  def stub_http_request(response)
    mock_http = Minitest::Mock.new
    mock_http.expect :use_ssl=, nil, [ Object ]
    mock_http.expect :open_timeout=, nil, [ 5 ]
    mock_http.expect :read_timeout=, nil, [ 5 ]
    mock_http.expect :request, response, [ Net::HTTP::Post ]

    Net::HTTP.stub :new, mock_http do
      yield
    end
  end
end
