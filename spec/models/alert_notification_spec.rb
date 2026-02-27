require "rails_helper"

RSpec.describe AlertNotification, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:alert) }
    it { is_expected.to belong_to(:notification_channel) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
  end

  describe "scopes" do
    describe ".pending" do
      it "returns only pending notifications" do
        pending = create(:alert_notification, status: "pending")
        sent = create(:alert_notification, :sent)
        expect(described_class.pending).to include(pending)
        expect(described_class.pending).not_to include(sent)
      end
    end

    describe ".failed" do
      it "returns only failed notifications" do
        failed = create(:alert_notification, :failed)
        sent = create(:alert_notification, :sent)
        expect(described_class.failed).to include(failed)
        expect(described_class.failed).not_to include(sent)
      end
    end
  end

  describe "status predicates" do
    it "#pending? returns true when pending" do
      expect(build(:alert_notification, status: "pending").pending?).to be true
    end

    it "#sent? returns true when sent" do
      expect(build(:alert_notification, :sent).sent?).to be true
    end

    it "#failed? returns true when failed" do
      expect(build(:alert_notification, :failed).failed?).to be true
    end
  end

  describe "#mark_sent!" do
    it "updates status to sent and sets sent_at" do
      notification = create(:alert_notification, status: "pending")
      allow(notification.notification_channel).to receive(:record_success!)

      freeze_time do
        notification.mark_sent!
        expect(notification.reload.status).to eq("sent")
        expect(notification.reload.sent_at).to be_within(1.second).of(Time.current)
      end
    end

    it "calls record_success! on the notification channel" do
      notification = create(:alert_notification, status: "pending")
      expect(notification.notification_channel).to receive(:record_success!)
      notification.mark_sent!
    end
  end

  describe "#mark_failed!" do
    it "updates status to failed and records the error message" do
      notification = create(:alert_notification, status: "pending")
      allow(notification.notification_channel).to receive(:record_failure!)

      notification.mark_failed!("timeout")
      expect(notification.reload.status).to eq("failed")
      expect(notification.reload.error_message).to eq("timeout")
    end

    it "calls record_failure! on the notification channel" do
      notification = create(:alert_notification, status: "pending")
      expect(notification.notification_channel).to receive(:record_failure!)
      notification.mark_failed!("error")
    end
  end
end
