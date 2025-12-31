class AlertRule < ApplicationRecord
  belongs_to :project
  has_many :alert_rule_channels, dependent: :destroy
  has_many :notification_channels, through: :alert_rule_channels
  has_many :alerts, dependent: :destroy

  METRIC_TYPES = %w[apdex error_rate throughput response_time p95 p99 custom].freeze
  OPERATORS = %w[gt gte lt lte eq].freeze
  AGGREGATIONS = %w[avg max min sum count p95 p99].freeze
  STATUSES = %w[ok alerting recovering].freeze
  SEVERITIES = %w[info warning critical].freeze

  validates :name, presence: true
  validates :metric_type, presence: true, inclusion: { in: METRIC_TYPES }
  validates :operator, presence: true, inclusion: { in: OPERATORS }
  validates :threshold, presence: true, numericality: true
  validates :aggregation, inclusion: { in: AGGREGATIONS }
  validates :window_minutes, numericality: { greater_than: 0 }
  validates :cooldown_minutes, numericality: { greater_than_or_equal_to: 0 }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :metric_name, presence: true, if: :custom_metric?

  scope :enabled, -> { where(enabled: true) }
  scope :alerting, -> { where(status: "alerting") }
  scope :by_metric_type, ->(type) { where(metric_type: type) }

  def custom_metric?
    metric_type == "custom"
  end

  def condition_met?(value)
    case operator
    when "gt"  then value > threshold
    when "gte" then value >= threshold
    when "lt"  then value < threshold
    when "lte" then value <= threshold
    when "eq"  then value == threshold
    else false
    end
  end

  def in_cooldown?
    return false unless last_triggered_at
    last_triggered_at > cooldown_minutes.minutes.ago
  end

  def trigger!(value:, endpoint: nil, environment: nil)
    return if in_cooldown?

    transaction do
      update!(
        status: "alerting",
        last_triggered_at: Time.current
      )

      alerts.create!(
        project: project,
        severity: severity,
        metric_type: metric_type,
        operator: operator,
        threshold: threshold,
        value: value,
        endpoint: endpoint || self.endpoint,
        environment: environment || self.environment,
        triggered_at: Time.current,
        message: build_message(value)
      )
    end
  end

  def resolve!
    return unless status == "alerting"

    transaction do
      update!(status: "ok")

      alerts.firing.each do |alert|
        alert.update!(status: "resolved", resolved_at: Time.current)
      end
    end
  end

  def human_condition
    op_text = case operator
    when "gt" then ">"
    when "gte" then ">="
    when "lt" then "<"
    when "lte" then "<="
    when "eq" then "="
    end

    "#{metric_display} #{op_text} #{threshold_display}"
  end

  private

  def metric_display
    case metric_type
    when "apdex" then "Apdex"
    when "error_rate" then "Error rate"
    when "throughput" then "Throughput"
    when "response_time" then "Response time"
    when "p95" then "P95 latency"
    when "p99" then "P99 latency"
    when "custom" then metric_name
    end
  end

  def threshold_display
    case metric_type
    when "error_rate" then "#{threshold}%"
    when "response_time", "p95", "p99" then "#{threshold}ms"
    when "throughput" then "#{threshold} rpm"
    else threshold.to_s
    end
  end

  def build_message(value)
    "#{metric_display} is #{format_value(value)} (threshold: #{threshold_display})"
  end

  def format_value(value)
    case metric_type
    when "error_rate" then "#{value.round(2)}%"
    when "response_time", "p95", "p99" then "#{value.round(0)}ms"
    when "throughput" then "#{value.round(0)} rpm"
    when "apdex" then value.round(2).to_s
    else value.to_s
    end
  end
end
