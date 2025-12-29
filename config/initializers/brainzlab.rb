# frozen_string_literal: true

# Self-tracking for Pulse APM
# Uses direct database inserts for traces to avoid HTTP infinite loops
# Sends to Recall and Reflex for cross-service monitoring
#
# Set BRAINZLAB_SDK_ENABLED=false to disable SDK initialization
# Useful for running migrations before SDK is ready

# Skip during asset precompilation or when explicitly disabled
return if ENV["BRAINZLAB_SDK_ENABLED"] == "false"
return if ENV["SECRET_KEY_BASE_DUMMY"].present?

BrainzLab.configure do |config|
  # App name for auto-provisioning projects
  config.app_name = "pulse"

  # Enable Recall logging (send logs to Recall)
  config.recall_enabled = ENV.fetch("RECALL_ENABLED", "true") == "true"
  config.recall_url = ENV.fetch("RECALL_URL", "http://recall:3000")
  config.recall_master_key = ENV["RECALL_MASTER_KEY"]
  config.recall_min_level = Rails.env.production? ? :info : :debug

  # Enable Reflex error tracking (send errors to Reflex)
  config.reflex_enabled = ENV.fetch("REFLEX_ENABLED", "true") == "true"
  config.reflex_url = ENV.fetch("REFLEX_URL", "http://reflex:3000")
  config.reflex_master_key = ENV["REFLEX_MASTER_KEY"]

  # Buffer settings for development
  config.recall_buffer_size = 1 if Rails.env.development?  # Send logs immediately in dev

  # Disable Pulse SDK (we use direct DB inserts for self-tracking)
  config.pulse_enabled = false

  # Exclude common Rails exceptions
  config.reflex_excluded_exceptions = [
    "ActionController::RoutingError",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::UnknownFormat"
  ]

  # Service identification
  config.service = "pulse"
  config.environment = Rails.env

  # Ignore internal BrainzLab hosts to prevent infinite recursion
  # when SDK instrumentation logs HTTP calls to other services
  config.http_ignore_hosts = %w[localhost 127.0.0.1 recall reflex pulse]
end

# Middleware to capture request timing for self-tracking
class PulseSelfTrackMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    Thread.current[:pulse_request_id] = request.request_id
    Thread.current[:pulse_request_started_at] = Time.now.utc
    Thread.current[:pulse_request_method] = request.request_method
    Thread.current[:pulse_request_path] = request.path

    status, headers, response = @app.call(env)

    [status, headers, response]
  ensure
    Thread.current[:pulse_request_id] = nil
    Thread.current[:pulse_request_started_at] = nil
    Thread.current[:pulse_request_method] = nil
    Thread.current[:pulse_request_path] = nil
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::RequestId, PulseSelfTrackMiddleware

Rails.application.config.after_initialize do
  # Skip if running migrations or if tables don't exist yet
  next unless ActiveRecord::Base.connection.table_exists?(:projects) rescue false

  # Provision Recall and Reflex projects (auto-creates project in each service)
  BrainzLab::Recall.ensure_provisioned! if BrainzLab.configuration.recall_enabled
  BrainzLab::Reflex.ensure_provisioned! if BrainzLab.configuration.reflex_enabled

  # Find or create the pulse project for self-tracking
  project = Project.find_or_create_by!(name: "pulse") do |p|
    p.platform_project_id = "pls_self_#{SecureRandom.hex(8)}"
    p.environment = Rails.env
  end

  # Generate API key if not present (only if settings column exists)
  if project.respond_to?(:settings) && project.settings.is_a?(Hash)
    unless project.settings["api_key"]
      project.settings["api_key"] = "pls_self_#{SecureRandom.hex(24)}"
      project.save!
    end
  end

  # Store project_id instead of the instance to avoid class reloading issues in development
  # (Project class gets reloaded but the cached instance becomes stale)
  pulse_project_id = project.id

  Rails.logger.info "[Pulse] Self-tracking enabled for project: #{project.id}"
  Rails.logger.info "[Pulse] Recall logging: #{BrainzLab.configuration.recall_enabled ? 'enabled' : 'disabled'}"
  Rails.logger.info "[Pulse] Reflex error tracking: #{BrainzLab.configuration.reflex_enabled ? 'enabled' : 'disabled'}"

  # Subscribe to request completion events for Recall logging and self-tracking
  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    payload = event.payload

    # Skip all API ingest endpoints to avoid self-tracking noise
    next if payload[:path]&.start_with?("/api/v1/")

    # Log to Recall (if enabled)
    if BrainzLab.configuration.recall_enabled
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

    # Self-track to Pulse via direct DB insert (using raw SQL to skip validations)
    started_at = Thread.current[:pulse_request_started_at]
    next unless started_at

    ended_at = Time.now.utc
    duration_ms = ((ended_at - started_at) * 1000).round(2)

    begin
      # Use raw SQL to avoid uniqueness validation and TimescaleDB index issues
      conn = ActiveRecord::Base.connection
      conn.execute(<<~SQL)
        INSERT INTO traces (
          id, project_id, trace_id, name, kind, started_at, ended_at, duration_ms,
          request_method, request_path, controller, action, status, environment,
          host, commit, error, view_duration_ms, db_duration_ms, created_at, updated_at
        ) VALUES (
          #{conn.quote(SecureRandom.uuid)},
          #{conn.quote(pulse_project_id)},
          #{conn.quote(Thread.current[:pulse_request_id] || SecureRandom.uuid)},
          #{conn.quote("#{payload[:method]} #{payload[:path]}")},
          'request',
          #{conn.quote(started_at)},
          #{conn.quote(ended_at)},
          #{duration_ms},
          #{conn.quote(payload[:method])},
          #{conn.quote(payload[:path])},
          #{conn.quote(payload[:controller])},
          #{conn.quote(payload[:action])},
          #{payload[:status].to_i},
          #{conn.quote(Rails.env)},
          #{conn.quote(Socket.gethostname)},
          #{conn.quote(ENV["GIT_COMMIT"] || `git rev-parse HEAD 2>/dev/null`.strip.presence)},
          #{payload[:status].to_i >= 500},
          #{payload[:view_runtime]&.round(1) || 0},
          #{payload[:db_runtime]&.round(1) || 0},
          #{conn.quote(ended_at)},
          #{conn.quote(ended_at)}
        )
      SQL
    rescue StandardError => e
      Rails.logger.error "[Pulse] Self-tracking failed: #{e.message}"
    end
  end

  # Subscribe to ActiveJob events for job tracing
  ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]

    duration_ms = event.duration.round(2)
    ended_at = Time.current
    started_at = ended_at - (duration_ms / 1000.0)

    begin
      # Use raw SQL to avoid uniqueness validation and TimescaleDB index issues
      conn = ActiveRecord::Base.connection
      conn.execute(<<~SQL)
        INSERT INTO traces (
          id, project_id, trace_id, name, kind, started_at, ended_at, duration_ms,
          job_class, job_id, queue, environment, host, commit, error, executions,
          created_at, updated_at
        ) VALUES (
          #{conn.quote(SecureRandom.uuid)},
          #{conn.quote(pulse_project_id)},
          #{conn.quote(job.job_id || SecureRandom.uuid)},
          #{conn.quote("Job #{job.class.name}")},
          'job',
          #{conn.quote(started_at)},
          #{conn.quote(ended_at)},
          #{duration_ms},
          #{conn.quote(job.class.name)},
          #{conn.quote(job.job_id)},
          #{conn.quote(job.queue_name)},
          #{conn.quote(Rails.env)},
          #{conn.quote(Socket.gethostname)},
          #{conn.quote(ENV["GIT_COMMIT"] || `git rev-parse HEAD 2>/dev/null`.strip.presence)},
          false,
          #{job.executions},
          #{conn.quote(ended_at)},
          #{conn.quote(ended_at)}
        )
      SQL
    rescue StandardError => e
      Rails.logger.error "[Pulse] Job self-tracking failed: #{e.message}"
    end
  end

  # Subscribe to job errors
  ActiveSupport::Notifications.subscribe("discard.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    error = event.payload[:error]

    next unless error

    duration_ms = event.duration.round(2)
    ended_at = Time.current
    started_at = ended_at - (duration_ms / 1000.0)

    begin
      # Use raw SQL to avoid uniqueness validation and TimescaleDB index issues
      conn = ActiveRecord::Base.connection
      conn.execute(<<~SQL)
        INSERT INTO traces (
          id, project_id, trace_id, name, kind, started_at, ended_at, duration_ms,
          job_class, job_id, queue, environment, host, commit, error, error_class,
          error_message, executions, created_at, updated_at
        ) VALUES (
          #{conn.quote(SecureRandom.uuid)},
          #{conn.quote(pulse_project_id)},
          #{conn.quote(job.job_id || SecureRandom.uuid)},
          #{conn.quote("Job #{job.class.name}")},
          'job',
          #{conn.quote(started_at)},
          #{conn.quote(ended_at)},
          #{duration_ms},
          #{conn.quote(job.class.name)},
          #{conn.quote(job.job_id)},
          #{conn.quote(job.queue_name)},
          #{conn.quote(Rails.env)},
          #{conn.quote(Socket.gethostname)},
          #{conn.quote(ENV["GIT_COMMIT"] || `git rev-parse HEAD 2>/dev/null`.strip.presence)},
          true,
          #{conn.quote(error.class.name)},
          #{conn.quote(error.message&.first(1000))},
          #{job.executions},
          #{conn.quote(ended_at)},
          #{conn.quote(ended_at)}
        )
      SQL
    rescue StandardError => e
      Rails.logger.error "[Pulse] Job error self-tracking failed: #{e.message}"
    end
  end
end
