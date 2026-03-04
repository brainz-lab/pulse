# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class RecallClient
  BASE_URL = ENV.fetch("BRAINZLAB_RECALL_URL", "http://localhost:4001")
  TIMEOUT = 5

  def self.logs_url_for(request_id:, since:, until_time:)
    params = URI.encode_www_form(
      request_id: request_id,
      since: since.iso8601,
      until: until_time.iso8601
    )
    "#{external_url}/dashboard/logs?#{params}"
  end

  def self.fetch_logs(request_id:, api_key:, limit: 20)
    uri = URI("#{BASE_URL}/api/v1/logs?request_id=#{URI.encode_www_form_component(request_id)}&limit=#{limit}")
    req = Net::HTTP::Get.new(uri)
    req["X-API-Key"] = api_key
    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: TIMEOUT, open_timeout: TIMEOUT) { |http| http.request(req) }
    JSON.parse(response.body) if response.code == "200"
  rescue => e
    Rails.logger.warn("RecallClient error: #{e.message}")
    nil
  end

  def self.external_url
    ENV.fetch("BRAINZLAB_RECALL_EXTERNAL_URL", "http://recall.brainzlab.local")
  end
end
