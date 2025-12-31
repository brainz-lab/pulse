class NotificationChannel < ApplicationRecord
  belongs_to :project
  has_many :alert_rule_channels, dependent: :destroy
  has_many :alert_rules, through: :alert_rule_channels
  has_many :alert_notifications, dependent: :destroy

  KINDS = %w[webhook email slack pagerduty].freeze

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :config, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :by_kind, ->(kind) { where(kind: kind) }

  def webhook?
    kind == "webhook"
  end

  def email?
    kind == "email"
  end

  def slack?
    kind == "slack"
  end

  def pagerduty?
    kind == "pagerduty"
  end

  def record_success!
    update!(
      last_used_at: Time.current,
      success_count: success_count + 1
    )
  end

  def record_failure!
    update!(
      last_used_at: Time.current,
      failure_count: failure_count + 1
    )
  end

  # Webhook config helpers
  def webhook_url
    config["url"]
  end

  def webhook_headers
    config["headers"] || {}
  end

  # Email config helpers
  def email_addresses
    config["addresses"] || []
  end

  # Slack config helpers
  def slack_webhook_url
    config["webhook_url"]
  end

  def slack_channel
    config["channel"]
  end

  # PagerDuty config helpers
  def pagerduty_integration_key
    config["integration_key"]
  end

  def pagerduty_severity
    config["severity"] || "error"
  end
end
