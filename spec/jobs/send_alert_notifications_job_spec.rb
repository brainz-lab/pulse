require "rails_helper"

RSpec.describe SendAlertNotificationsJob, type: :job do
  describe "#perform" do
    let(:project)  { create(:project) }
    let(:rule)     { create(:alert_rule, project: project) }
    let(:channel)  { create(:notification_channel, project: project) }
    let!(:alert)   { create(:alert, project: project, alert_rule: rule) }

    it "calls NotificationSender#send! for each pending notification" do
      notification = create(:alert_notification, alert: alert,
                            notification_channel: channel, status: :pending)
      sender = instance_double(NotificationSender)
      expect(NotificationSender).to receive(:new).with(notification: notification).and_return(sender)
      expect(sender).to receive(:send!)
      described_class.perform_now(alert.id)
    end

    it "does not process sent notifications" do
      create(:alert_notification, :sent, alert: alert, notification_channel: channel)
      expect(NotificationSender).not_to receive(:new)
      described_class.perform_now(alert.id)
    end

    it "does not process failed notifications" do
      create(:alert_notification, :failed, alert: alert, notification_channel: channel)
      expect(NotificationSender).not_to receive(:new)
      described_class.perform_now(alert.id)
    end

    it "does nothing when the alert does not exist" do
      expect(NotificationSender).not_to receive(:new)
      expect { described_class.perform_now("nonexistent-id") }.not_to raise_error
    end

    it "sends all pending notifications for an alert" do
      channel2 = create(:notification_channel, project: project, name: "slack-channel")
      notif1   = create(:alert_notification, alert: alert, notification_channel: channel,  status: :pending)
      notif2   = create(:alert_notification, alert: alert, notification_channel: channel2, status: :pending)

      sender1 = instance_double(NotificationSender)
      sender2 = instance_double(NotificationSender)
      allow(NotificationSender).to receive(:new).with(notification: notif1).and_return(sender1)
      allow(NotificationSender).to receive(:new).with(notification: notif2).and_return(sender2)
      expect(sender1).to receive(:send!)
      expect(sender2).to receive(:send!)

      described_class.perform_now(alert.id)
    end

    it "enqueues on the default queue" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
