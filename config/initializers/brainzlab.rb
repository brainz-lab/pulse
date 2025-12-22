# frozen_string_literal: true

BrainzLab.configure do |config|
  # App name for auto-provisioning projects
  config.app_name = "pulse"

  # Recall logging configuration
  config.recall_url = ENV.fetch("RECALL_URL", "http://recall.localhost")
  config.recall_master_key = ENV["RECALL_MASTER_KEY"]
  config.recall_min_level = Rails.env.production? ? :info : :debug

  # Reflex error tracking configuration
  config.reflex_enabled = true
  config.reflex_url = ENV.fetch("REFLEX_URL", "http://reflex.localhost")
  config.reflex_master_key = ENV["REFLEX_MASTER_KEY"]

  # Exclude common Rails exceptions
  config.reflex_excluded_exceptions = [
    "ActionController::RoutingError",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::UnknownFormat"
  ]

  # Service identification
  config.service = "pulse"
  config.environment = Rails.env
end

# Hook into Rails request logging via notifications
Rails.application.config.after_initialize do
  # Provision the projects early so we have credentials
  BrainzLab::Recall.ensure_provisioned!
  BrainzLab::Reflex.ensure_provisioned!

  next unless BrainzLab.configuration.valid?

  # Subscribe to request completion events
  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    payload = event.payload

    BrainzLab::Recall.info("#{payload[:method]} #{payload[:path]}",
      controller: payload[:controller],
      action: payload[:action],
      status: payload[:status],
      duration_ms: event.duration.round(1),
      view_ms: payload[:view_runtime]&.round(1),
      db_ms: payload[:db_runtime]&.round(1),
      format: payload[:format],
      params: payload[:params].except("controller", "action").to_h
    )
  end

  Rails.logger.info "[BrainzLab] Recall logging enabled for pulse"
  Rails.logger.info "[BrainzLab] Reflex error tracking: #{BrainzLab.configuration.reflex_enabled ? 'enabled' : 'disabled'}"
end
