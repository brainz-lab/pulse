class AlertsChannel < ApplicationCable::Channel
  def subscribed
    project = Project.find_by(id: params[:project_id])
    if project
      stream_for project
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Broadcast helpers for use throughout the application
  class << self
    def broadcast_alert_firing(project, alert)
      broadcast_to(project, {
        type: "firing",
        alert: alert_payload(alert)
      })
    end

    def broadcast_alert_resolved(project, alert_rule)
      broadcast_to(project, {
        type: "resolved",
        alert_rule_id: alert_rule.id,
        name: alert_rule.name
      })
    end

    def broadcast_alert_rule_created(project, alert_rule)
      broadcast_to(project, {
        type: "alert_rule_created",
        alert_rule: alert_rule_payload(alert_rule)
      })
    end

    def broadcast_alert_rule_updated(project, alert_rule)
      broadcast_to(project, {
        type: "alert_rule_updated",
        alert_rule: alert_rule_payload(alert_rule)
      })
    end

    def broadcast_alert_rule_deleted(project, alert_rule_id)
      broadcast_to(project, {
        type: "alert_rule_deleted",
        alert_rule_id: alert_rule_id
      })
    end

    def broadcast_notification_channel_created(project, channel)
      broadcast_to(project, {
        type: "notification_channel_created",
        notification_channel: notification_channel_payload(channel)
      })
    end

    def broadcast_notification_channel_updated(project, channel)
      broadcast_to(project, {
        type: "notification_channel_updated",
        notification_channel: notification_channel_payload(channel)
      })
    end

    def broadcast_notification_channel_deleted(project, channel_id)
      broadcast_to(project, {
        type: "notification_channel_deleted",
        notification_channel_id: channel_id
      })
    end

    private

    def alert_payload(alert)
      {
        id: alert.id,
        rule_name: alert.alert_rule.name,
        severity: alert.severity,
        message: alert.message,
        triggered_at: alert.triggered_at.iso8601
      }
    end

    def alert_rule_payload(alert_rule)
      {
        id: alert_rule.id,
        name: alert_rule.name,
        metric_type: alert_rule.metric_type,
        operator: alert_rule.operator,
        threshold: alert_rule.threshold,
        severity: alert_rule.severity,
        enabled: alert_rule.enabled,
        status: alert_rule.status
      }
    end

    def notification_channel_payload(channel)
      {
        id: channel.id,
        name: channel.name,
        kind: channel.kind,
        enabled: channel.enabled
      }
    end
  end
end
