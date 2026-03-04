# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class SentinelClient
  BASE_URL = ENV.fetch("BRAINZLAB_SENTINEL_URL", "http://localhost:4014")
  TIMEOUT = 5

  def self.host_metrics(host:, since:, api_key:)
    params = URI.encode_www_form(host: host, since: since.iso8601)
    uri = URI("#{BASE_URL}/api/v1/metrics?#{params}")
    req = Net::HTTP::Get.new(uri)
    req["X-API-Key"] = api_key
    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: TIMEOUT, open_timeout: TIMEOUT) { |http| http.request(req) }
    JSON.parse(response.body) if response.code == "200"
  rescue => e
    Rails.logger.warn("SentinelClient error: #{e.message}")
    nil
  end

  def self.external_url
    ENV.fetch("BRAINZLAB_SENTINEL_EXTERNAL_URL", "http://sentinel.brainzlab.local")
  end
end
