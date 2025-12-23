class SendAlertNotificationsJob < ApplicationJob
  queue_as :default

  def perform(alert_id)
    alert = Alert.find_by(id: alert_id)
    return unless alert

    alert.alert_notifications.pending.find_each do |notification|
      NotificationSender.new(notification: notification).send!
    end
  end
end
