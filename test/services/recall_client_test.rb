require "test_helper"
require "webmock/minitest"

class RecallClientTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "logs_url_for generates correct URL with params" do
    since = Time.utc(2026, 3, 1, 12, 0, 0)
    until_time = Time.utc(2026, 3, 1, 13, 0, 0)

    url = RecallClient.logs_url_for(
      request_id: "req-abc123",
      since: since,
      until_time: until_time
    )

    assert_includes url, "recall.brainzlab.local/dashboard/logs?"
    assert_includes url, "request_id=req-abc123"
    assert_includes url, "since=2026-03-01T12%3A00%3A00Z"
    assert_includes url, "until=2026-03-01T13%3A00%3A00Z"
  end

  test "logs_url_for uses BRAINZLAB_RECALL_EXTERNAL_URL when set" do
    original = ENV["BRAINZLAB_RECALL_EXTERNAL_URL"]
    ENV["BRAINZLAB_RECALL_EXTERNAL_URL"] = "https://recall.example.com"

    url = RecallClient.logs_url_for(
      request_id: "req-123",
      since: Time.current,
      until_time: Time.current + 1.hour
    )
    assert_includes url, "https://recall.example.com"
  ensure
    if original
      ENV["BRAINZLAB_RECALL_EXTERNAL_URL"] = original
    else
      ENV.delete("BRAINZLAB_RECALL_EXTERNAL_URL")
    end
  end

  test "fetch_logs returns parsed JSON on success" do
    logs = [{ "message" => "Test log", "timestamp" => "2026-03-01T12:00:00Z" }]

    stub_request(:get, %r{localhost:4001/api/v1/logs})
      .with(headers: { "X-API-Key" => "test-key" })
      .to_return(status: 200, body: logs.to_json, headers: { "Content-Type" => "application/json" })

    result = RecallClient.fetch_logs(request_id: "req-abc123", api_key: "test-key")
    assert_equal logs, result
  end

  test "fetch_logs returns nil on non-200 response" do
    stub_request(:get, %r{localhost:4001/api/v1/logs})
      .to_return(status: 404, body: { error: "not found" }.to_json)

    result = RecallClient.fetch_logs(request_id: "req-abc123", api_key: "test-key")
    assert_nil result
  end

  test "fetch_logs returns nil and logs warning on network error" do
    stub_request(:get, %r{localhost:4001/api/v1/logs})
      .to_timeout

    result = RecallClient.fetch_logs(request_id: "req-abc123", api_key: "test-key")
    assert_nil result
  end

  test "fetch_logs passes limit parameter" do
    stub_request(:get, %r{localhost:4001/api/v1/logs})
      .with(query: hash_including("request_id" => "req-123", "limit" => "5"))
      .to_return(status: 200, body: [].to_json)

    result = RecallClient.fetch_logs(request_id: "req-123", api_key: "key", limit: 5)
    assert_equal [], result
  end

  test "external_url returns default when env not set" do
    url = RecallClient.external_url
    assert_equal "http://recall.brainzlab.local", url
  end
end
