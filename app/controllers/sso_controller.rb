class SsoController < ApplicationController
  # GET /sso/callback - Callback from Platform SSO
  def callback
    token = params[:token]

    if token.blank?
      redirect_to platform_external_url, allow_other_host: true
      return
    end

    # Validate token with Platform (internal Docker network)
    user_info = validate_sso_token(token)

    if user_info[:valid]
      session[:platform_user_id] = user_info[:user_id]
      session[:platform_project_id] = user_info[:project_id]
      session[:platform_organization_id] = user_info[:organization_id]
      session[:project_slug] = user_info[:project_slug]
      session[:user_email] = user_info[:user_email]
      session[:user_name] = user_info[:user_name]

      redirect_to params[:return_to] || dashboard_root_path
    else
      redirect_to "#{platform_external_url}/login?error=sso_failed", allow_other_host: true
    end
  end

  private

  def validate_sso_token(token)
    uri = URI("#{platform_internal_url}/api/v1/sso/validate")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['X-Service-Key'] = ENV['SERVICE_KEY']
    request.body = { token: token, product: 'pulse' }.to_json

    response = http.request(request)

    if response.code == '200'
      JSON.parse(response.body, symbolize_names: true).merge(valid: true)
    else
      { valid: false }
    end
  rescue => e
    Rails.logger.error("[SSO] Token validation failed: #{e.message}")
    { valid: false }
  end

  # Internal URL for service-to-service API calls (Docker network)
  def platform_internal_url
    ENV['BRAINZLAB_PLATFORM_URL'] || 'http://platform:3000'
  end

  # External URL for browser redirects (Traefik)
  def platform_external_url
    ENV['BRAINZLAB_PLATFORM_EXTERNAL_URL'] || 'http://platform.localhost'
  end
end
