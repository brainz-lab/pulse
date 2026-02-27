module ApiHelpers
  # Returns headers for a project authenticated via its pls_ API key.
  def auth_headers(project)
    api_key = project.settings&.dig("api_key") || "pls_testkey_#{project.id}"
    { "Authorization" => "Bearer #{api_key}" }
  end

  # Returns headers for the master key (projects provisioning endpoint).
  def master_key_headers(key = "test_master_key")
    { "X-Master-Key" => key }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
