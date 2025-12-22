# frozen_string_literal: true

BrainzLab.configure do |config|
  # App name for auto-provisioning Recall project
  config.app_name = "pulse"

  # Recall logging configuration
  config.recall_url = ENV.fetch("RECALL_URL", "http://recall.localhost")
  config.recall_master_key = ENV["RECALL_MASTER_KEY"]
  config.recall_min_level = Rails.env.production? ? :info : :debug

  # Service identification
  config.service = "pulse"
  config.environment = Rails.env

  # Disable Reflex error tracking (can enable if you want Pulse errors in Reflex)
  config.reflex_enabled = false
end

# Hook into Rails request logging via notifications
Rails.application.config.after_initialize do
  # Provision the project early so we have credentials
  BrainzLab::Recall.ensure_provisioned!

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
end
