require "test_helper"
require "webmock/minitest"

class ReflexClientTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "error_url_for generates correct URL with params" do
    since = Time.utc(2026, 3, 1, 12, 0, 0)

    url = ReflexClient.error_url_for(
      error_class: "NoMethodError",
      since: since
    )

    assert_includes url, "reflex.brainzlab.local/dashboard/errors?"
    assert_includes url, "error_class=NoMethodError"
    assert_includes url, "since=2026-03-01T12%3A00%3A00Z"
  end

  test "error_url_for encodes special characters in error class" do
    url = ReflexClient.error_url_for(
      error_class: "ActiveRecord::RecordNotFound",
      since: Time.current
    )

    assert_includes url, "error_class=ActiveRecord%3A%3ARecordNotFound"
  end

  test "fetch_error_group returns parsed JSON on success" do
    error_data = { "error_class" => "NoMethodError", "count" => 42, "status" => "open" }

    stub_request(:get, %r{localhost:4002/api/v1/errors})
      .with(headers: { "X-API-Key" => "test-key" })
      .to_return(status: 200, body: error_data.to_json, headers: { "Content-Type" => "application/json" })

    result = ReflexClient.fetch_error_group(error_class: "NoMethodError", api_key: "test-key")
    assert_equal error_data, result
  end

  test "fetch_error_group returns nil on non-200 response" do
    stub_request(:get, %r{localhost:4002/api/v1/errors})
      .to_return(status: 500, body: { error: "internal" }.to_json)

    result = ReflexClient.fetch_error_group(error_class: "NoMethodError", api_key: "test-key")
    assert_nil result
  end

  test "fetch_error_group returns nil on network error" do
    stub_request(:get, %r{localhost:4002/api/v1/errors})
      .to_timeout

    result = ReflexClient.fetch_error_group(error_class: "NoMethodError", api_key: "test-key")
    assert_nil result
  end

  test "external_url returns default when env not set" do
    url = ReflexClient.external_url
    assert_equal "http://reflex.brainzlab.local", url
  end
end
