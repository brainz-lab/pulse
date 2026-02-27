require "rails_helper"

RSpec.describe NotificationSender do
  let(:project) { create(:project) }
  let(:rule)    { create(:alert_rule, project: project) }
  let(:alert)   { create(:alert, project: project, alert_rule: rule) }

  describe "#send!" do
    context "webhook channel" do
      let(:channel) { create(:notification_channel, :webhook, project: project) }
      let(:notification) { create(:alert_notification, alert: alert, notification_channel: channel) }

      it "POSTs the alert payload to the webhook URL" do
        stub = stub_request(:post, channel.webhook_url).to_return(status: 200, body: "ok")
        described_class.new(notification: notification).send!
        expect(stub).to have_been_requested
      end

      it "marks the notification as sent on success" do
        stub_request(:post, channel.webhook_url).to_return(status: 200, body: "ok")
        described_class.new(notification: notification).send!
        expect(notification.reload.status).to eq("sent")
      end

      it "marks the notification as failed when the server returns an error" do
        stub_request(:post, channel.webhook_url).to_return(status: 500, body: "Internal Server Error")
        described_class.new(notification: notification).send!
        expect(notification.reload.status).to eq("failed")
        expect(notification.reload.error_message).to include("500")
      end

      it "marks the notification as failed on network timeout" do
        stub_request(:post, channel.webhook_url).to_timeout
        described_class.new(notification: notification).send!
        expect(notification.reload.status).to eq("failed")
      end
    end

    context "slack channel" do
      let(:channel) { create(:notification_channel, :slack, project: project) }
      let(:notification) { create(:alert_notification, alert: alert, notification_channel: channel) }

      it "POSTs a Slack-formatted payload to the Slack webhook URL" do
        stub = stub_request(:post, channel.slack_webhook_url).to_return(status: 200, body: "ok")
        described_class.new(notification: notification).send!
        expect(stub).to have_been_requested
      end

      it "includes severity color in the payload" do
        stub_request(:post, channel.slack_webhook_url)
          .with { |req| JSON.parse(req.body).dig("attachments", 0, "color") == "#F59E0B" }
          .to_return(status: 200, body: "ok")
        described_class.new(notification: notification).send!
      end
    end

    context "pagerduty channel" do
      let(:channel) { create(:notification_channel, :pagerduty, project: project) }
      let(:notification) { create(:alert_notification, alert: alert, notification_channel: channel) }

      it "POSTs to the PagerDuty Events API" do
        stub = stub_request(:post, "https://events.pagerduty.com/v2/enqueue")
          .to_return(status: 202, body: '{"status":"success"}')
        described_class.new(notification: notification).send!
        expect(stub).to have_been_requested
      end

      it "includes the integration key in the payload" do
        stub_request(:post, "https://events.pagerduty.com/v2/enqueue")
          .with { |req| JSON.parse(req.body)["routing_key"] == "abc123" }
          .to_return(status: 202, body: '{"status":"success"}')
        described_class.new(notification: notification).send!
      end
    end

    context "email channel" do
      let(:channel) { create(:notification_channel, :email, project: project) }
      let(:notification) { create(:alert_notification, alert: alert, notification_channel: channel) }

      it "marks the notification as sent (logs only, no HTTP call)" do
        # Email is a stub/log implementation — no HTTP calls expected
        described_class.new(notification: notification).send!
        expect(notification.reload.status).to eq("sent")
      end
    end

    context "already sent notification" do
      let(:channel) { create(:notification_channel, project: project) }
      let(:notification) { create(:alert_notification, :sent, alert: alert, notification_channel: channel) }

      it "does not send again" do
        expect_any_instance_of(Net::HTTP).not_to receive(:request)
        described_class.new(notification: notification).send!
      end
    end
  end
end
