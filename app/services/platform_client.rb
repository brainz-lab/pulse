require "net/http"
require "json"

class PlatformClient
  class << self
    def validate_key(raw_key)
      return { valid: false } if raw_key.blank?

      uri = URI("#{platform_url}/api/v1/keys/validate")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request.body = { key: raw_key }.to_json

      response = http.request(request)

      if response.code == "200"
        data = JSON.parse(response.body, symbolize_names: true)

        # In development, allow any key if Platform says invalid
        if !data[:valid] && Rails.env.development? && raw_key.present?
          return dev_fallback(raw_key)
        end

        {
          valid: data[:valid],
          project_id: data[:project_id],
          organization_id: data[:organization_id],
          project_name: data[:project_name],
          product: data[:product],
          key_type: data[:key_type],
          plan: data[:plan],
          limits: data[:limits] || {},
          environment: data[:environment] || "live",
          features: data[:features] || { pulse: true },
          quota_remaining: data[:quota_remaining] || {}
        }
      else
        Rails.env.development? && raw_key.present? ? dev_fallback(raw_key) : { valid: false }
      end
    rescue StandardError => e
      Rails.logger.error("[PlatformClient] Key validation failed: #{e.message}")
      # In development, allow bypass if platform is not running
      Rails.env.development? && raw_key.present? ? dev_fallback(raw_key) : { valid: false }
    end

    def dev_fallback(raw_key)
      {
        valid: true,
        project_id: "dev_#{Digest::SHA256.hexdigest(raw_key)[0..7]}",
        project_name: "Development Project",
        environment: "development",
        features: { pulse: true },
        limits: {},
        quota_remaining: { traces: Float::INFINITY }
      }
    end

    def track_usage(project_id:, product:, metric:, count:)
      return if count <= 0

      Thread.new do
        uri = URI("#{platform_url}/api/v1/usage/track")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 5

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["X-Service-Key"] = service_key
        request.body = {
          project_id: project_id,
          product: product,
          metric: metric,
          count: count
        }.to_json

        http.request(request)
      rescue StandardError => e
        Rails.logger.error("[PlatformClient] Usage tracking failed: #{e.message}")
      end
    end

    private

    def platform_url
      ENV["BRAINZLAB_PLATFORM_URL"] || "http://localhost:2999"
    end

    def service_key
      ENV["SERVICE_KEY"] || Rails.application.credentials.dig(:service_key)
    end
  end
end
