require "test_helper"
require "webmock/minitest"

class SentinelClientTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "host_metrics returns parsed JSON on success" do
    metrics = { "cpu" => 45.2, "memory" => 72.1, "disk" => 55.0 }
    since = Time.utc(2026, 3, 1, 12, 0, 0)

    stub_request(:get, %r{localhost:4014/api/v1/metrics})
      .with(headers: { "X-API-Key" => "test-key" })
      .to_return(status: 200, body: metrics.to_json, headers: { "Content-Type" => "application/json" })

    result = SentinelClient.host_metrics(host: "web-1", since: since, api_key: "test-key")
    assert_equal metrics, result
  end

  test "host_metrics returns nil on non-200 response" do
    stub_request(:get, %r{localhost:4014/api/v1/metrics})
      .to_return(status: 503, body: { error: "unavailable" }.to_json)

    result = SentinelClient.host_metrics(host: "web-1", since: Time.current, api_key: "test-key")
    assert_nil result
  end

  test "host_metrics returns nil on network error" do
    stub_request(:get, %r{localhost:4014/api/v1/metrics})
      .to_timeout

    result = SentinelClient.host_metrics(host: "web-1", since: Time.current, api_key: "test-key")
    assert_nil result
  end

  test "host_metrics encodes host and since params" do
    since = Time.utc(2026, 3, 1, 12, 0, 0)

    stub_request(:get, "http://localhost:4014/api/v1/metrics?host=web-1&since=2026-03-01T12%3A00%3A00Z")
      .to_return(status: 200, body: {}.to_json)

    result = SentinelClient.host_metrics(host: "web-1", since: since, api_key: "test-key")
    assert_equal({}, result)
  end

  test "external_url returns default when env not set" do
    url = SentinelClient.external_url
    assert_equal "http://sentinel.brainzlab.local", url
  end
end
