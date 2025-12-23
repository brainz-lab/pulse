require 'net/http'
require 'json'

class NotificationSender
  def initialize(notification:)
    @notification = notification
    @channel = notification.notification_channel
    @alert = notification.alert
  end

  def send!
    return if @notification.sent?

    case @channel.kind
    when 'webhook'
      send_webhook
    when 'email'
      send_email
    when 'slack'
      send_slack
    when 'pagerduty'
      send_pagerduty
    end

    @notification.mark_sent!
  rescue StandardError => e
    @notification.mark_failed!(e.message)
    Rails.logger.error("[NotificationSender] Failed to send: #{e.message}")
  end

  private

  def send_webhook
    post_json(@channel.webhook_url, webhook_payload, @channel.webhook_headers)
  end

  def webhook_payload
    {
      alert_id: @alert.id,
      rule_name: @alert.alert_rule.name,
      severity: @alert.severity,
      status: @alert.status,
      metric_type: @alert.metric_type,
      value: @alert.value,
      threshold: @alert.threshold,
      message: @alert.message,
      endpoint: @alert.endpoint,
      environment: @alert.environment,
      triggered_at: @alert.triggered_at.iso8601,
      project: {
        id: @alert.project.id,
        name: @alert.project.name
      }
    }
  end

  def send_email
    # Placeholder for email sending
    # In production, would use ActionMailer or a service like SendGrid
    Rails.logger.info("[NotificationSender] Would send email to: #{@channel.email_addresses.join(', ')}")
    Rails.logger.info("[NotificationSender] Subject: [#{@alert.severity.upcase}] #{@alert.alert_rule.name}")
    Rails.logger.info("[NotificationSender] Body: #{@alert.message}")
  end

  def send_slack
    post_json(@channel.slack_webhook_url, slack_payload)
  end

  def slack_payload
    color = case @alert.severity
            when 'critical' then '#DC2626'
            when 'warning' then '#F59E0B'
            else '#6B7280'
            end

    {
      channel: @channel.slack_channel,
      attachments: [
        {
          color: color,
          title: "[#{@alert.severity.upcase}] #{@alert.alert_rule.name}",
          text: @alert.message,
          fields: [
            { title: 'Metric', value: @alert.metric_type, short: true },
            { title: 'Value', value: @alert.value.to_s, short: true },
            { title: 'Threshold', value: @alert.threshold.to_s, short: true },
            { title: 'Environment', value: @alert.environment || 'N/A', short: true }
          ],
          footer: "Pulse APM | #{@alert.project.name}",
          ts: @alert.triggered_at.to_i
        }
      ]
    }
  end

  def send_pagerduty
    post_json('https://events.pagerduty.com/v2/enqueue', pagerduty_payload)
  end

  def pagerduty_payload
    {
      routing_key: @channel.pagerduty_integration_key,
      event_action: 'trigger',
      dedup_key: "pulse-alert-#{@alert.alert_rule.id}",
      payload: {
        summary: "[#{@alert.severity.upcase}] #{@alert.alert_rule.name}: #{@alert.message}",
        severity: @channel.pagerduty_severity,
        source: "Pulse APM - #{@alert.project.name}",
        component: @alert.endpoint || 'application',
        group: @alert.environment || 'production',
        class: @alert.metric_type,
        custom_details: {
          alert_id: @alert.id,
          metric_type: @alert.metric_type,
          value: @alert.value,
          threshold: @alert.threshold,
          triggered_at: @alert.triggered_at.iso8601
        }
      }
    }
  end

  def post_json(url, payload, extra_headers = {})
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    extra_headers.each { |k, v| request[k] = v }
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "HTTP #{response.code}: #{response.body.to_s.truncate(200)}"
    end

    response
  end
end
