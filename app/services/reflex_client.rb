# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "cgi"

class ReflexClient
  BASE_URL = ENV.fetch("BRAINZLAB_REFLEX_URL", "http://localhost:4002")
  TIMEOUT = 5

  def self.error_url_for(error_class:, since:)
    params = URI.encode_www_form(error_class: error_class, since: since.iso8601)
    "#{external_url}/dashboard/errors?#{params}"
  end

  def self.fetch_error_group(error_class:, api_key:)
    uri = URI("#{BASE_URL}/api/v1/errors?error_class=#{CGI.escape(error_class)}&limit=1")
    req = Net::HTTP::Get.new(uri)
    req["X-API-Key"] = api_key
    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: TIMEOUT, open_timeout: TIMEOUT) { |http| http.request(req) }
    JSON.parse(response.body) if response.code == "200"
  rescue => e
    Rails.logger.warn("ReflexClient error: #{e.message}")
    nil
  end

  def self.external_url
    ENV.fetch("BRAINZLAB_REFLEX_EXTERNAL_URL", "http://reflex.brainzlab.local")
  end
end
