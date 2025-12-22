class SsoController < ApplicationController
  # GET /auth/sso - Callback from Platform SSO
  def callback
    token = params[:token]

    if token.blank?
      redirect_to ENV['BRAINZLAB_PLATFORM_URL'] || 'http://localhost:2999'
      return
    end

    # Validate token with Platform
    user_info = validate_sso_token(token)

    if user_info[:valid]
      session[:platform_user_id] = user_info[:user_id]
      session[:platform_project_id] = user_info[:project_id]
      session[:project_name] = user_info[:project_name]
      session[:user_email] = user_info[:email]

      redirect_to params[:return_to] || dashboard_root_path
    else
      redirect_to "#{platform_url}/login?error=sso_failed"
    end
  end

  private

  def validate_sso_token(token)
    uri = URI("#{platform_url}/api/v1/sso/validate")
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

  def platform_url
    ENV['BRAINZLAB_PLATFORM_URL'] || 'http://localhost:2999'
  end
end
