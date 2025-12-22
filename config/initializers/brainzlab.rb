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

# Hook into Rails logging - send all logs to Recall
Rails.application.config.after_initialize do
  # Provision the project early so we have credentials
  BrainzLab::Recall.ensure_provisioned!

  # Create a logger that sends to both Recall and the original Rails logger
  if BrainzLab.configuration.valid?
    original_logger = Rails.logger
    Rails.logger = BrainzLab::Recall::Logger.new(broadcast_to: original_logger)
    Rails.logger.info "BrainzLab Recall logging enabled for pulse"
  end
end
