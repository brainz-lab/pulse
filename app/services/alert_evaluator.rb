class AlertEvaluator
  def initialize(project:)
    @project = project
  end

  def evaluate_all!
    @project.alert_rules.enabled.find_each do |rule|
      evaluate_rule!(rule)
    end
  end

  def evaluate_rule!(rule)
    value = fetch_metric_value(rule)
    return unless value

    rule.update!(last_checked_at: Time.current)

    if rule.condition_met?(value)
      handle_alert_triggered(rule, value)
    else
      handle_alert_resolved(rule)
    end
  end

  private

  def fetch_metric_value(rule)
    since = rule.window_minutes.minutes.ago
    scope = build_trace_scope(rule, since)

    case rule.metric_type
    when 'apdex'
      ApdexCalculator.calculate(traces: scope, threshold: @project.apdex_t)
    when 'error_rate'
      calculate_error_rate(scope)
    when 'throughput'
      calculate_throughput(scope, since)
    when 'response_time'
      calculate_response_time(scope, rule.aggregation)
    when 'p95'
      calculate_percentile(scope, 0.95)
    when 'p99'
      calculate_percentile(scope, 0.99)
    when 'custom'
      fetch_custom_metric(rule)
    end
  end

  def build_trace_scope(rule, since)
    scope = @project.traces.where('started_at >= ?', since).where(kind: 'request')
    scope = scope.where(request_path: rule.endpoint) if rule.endpoint.present?
    scope = scope.where(environment: rule.environment) if rule.environment.present?
    scope
  end

  def calculate_error_rate(scope)
    total = scope.count
    return 0.0 if total == 0
    (scope.where(error: true).count.to_f / total * 100)
  end

  def calculate_throughput(scope, since)
    minutes = (Time.current - since) / 60.0
    scope.count / minutes
  end

  def calculate_response_time(scope, aggregation)
    case aggregation
    when 'avg' then scope.average(:duration_ms)
    when 'max' then scope.maximum(:duration_ms)
    when 'min' then scope.minimum(:duration_ms)
    when 'p95' then calculate_percentile(scope, 0.95)
    when 'p99' then calculate_percentile(scope, 0.99)
    else scope.average(:duration_ms)
    end
  end

  def calculate_percentile(scope, p)
    sorted = scope.order(:duration_ms)
    offset = (scope.count * p).to_i
    sorted.offset(offset).limit(1).pick(:duration_ms)
  end

  def fetch_custom_metric(rule)
    since = rule.window_minutes.minutes.ago
    points = @project.metric_points
                     .joins(:metric)
                     .where(metrics: { name: rule.metric_name })
                     .where('timestamp >= ?', since)

    case rule.aggregation
    when 'avg' then points.average(:value)
    when 'max' then points.maximum(:value)
    when 'min' then points.minimum(:value)
    when 'sum' then points.sum(:value)
    when 'count' then points.count
    else points.average(:value)
    end
  end

  def handle_alert_triggered(rule, value)
    alert = rule.trigger!(value: value)
    return unless alert

    # Queue notifications
    rule.notification_channels.enabled.find_each do |channel|
      alert.alert_notifications.create!(
        notification_channel: channel,
        status: 'pending'
      )
    end

    # Send notifications asynchronously
    SendAlertNotificationsJob.perform_later(alert.id)

    # Broadcast to dashboard
    broadcast_alert(alert)
  end

  def handle_alert_resolved(rule)
    return unless rule.status == 'alerting'

    rule.resolve!

    # Broadcast resolution to dashboard
    AlertsChannel.broadcast_to(@project, {
      type: 'resolved',
      alert_rule_id: rule.id,
      name: rule.name
    })
  end

  def broadcast_alert(alert)
    AlertsChannel.broadcast_to(@project, {
      type: 'firing',
      alert: {
        id: alert.id,
        rule_name: alert.alert_rule.name,
        severity: alert.severity,
        message: alert.message,
        triggered_at: alert.triggered_at.iso8601
      }
    })
  end
end
