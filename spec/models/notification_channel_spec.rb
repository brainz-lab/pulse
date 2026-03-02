require "rails_helper"

RSpec.describe NotificationChannel, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:alert_rule_channels).dependent(:destroy) }
    it { is_expected.to have_many(:alert_rules).through(:alert_rule_channels) }
    it { is_expected.to have_many(:alert_notifications).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
    it { is_expected.to validate_presence_of(:config) }

    it "validates name uniqueness scoped to project" do
      project = create(:project)
      create(:notification_channel, project: project, name: "Ops Webhook")
      duplicate = build(:notification_channel, project: project, name: "Ops Webhook")
      expect(duplicate).not_to be_valid
    end
  end

  describe "scopes" do
    describe ".enabled" do
      it "returns only enabled channels" do
        enabled = create(:notification_channel, enabled: true)
        disabled = create(:notification_channel, :disabled)
        expect(described_class.enabled).to include(enabled)
        expect(described_class.enabled).not_to include(disabled)
      end
    end
  end

  describe "kind predicates" do
    it "#webhook? returns true for webhook kind" do
      expect(build(:notification_channel, kind: "webhook").webhook?).to be true
    end

    it "#email? returns true for email kind" do
      expect(build(:notification_channel, :email).email?).to be true
    end

    it "#slack? returns true for slack kind" do
      expect(build(:notification_channel, :slack).slack?).to be true
    end

    it "#pagerduty? returns true for pagerduty kind" do
      expect(build(:notification_channel, :pagerduty).pagerduty?).to be true
    end
  end

  describe "config helpers" do
    it "#webhook_url returns the url from config" do
      ch = build(:notification_channel, kind: "webhook", config: { "url" => "https://hook.example.com" })
      expect(ch.webhook_url).to eq("https://hook.example.com")
    end

    it "#email_addresses returns the array from config" do
      ch = build(:notification_channel, :email)
      expect(ch.email_addresses).to eq([ "ops@example.com" ])
    end

    it "#slack_webhook_url returns the webhook_url from config" do
      ch = build(:notification_channel, :slack)
      expect(ch.slack_webhook_url).to eq("https://hooks.slack.com/services/T000/B000/xxx")
    end

    it "#pagerduty_integration_key returns the integration_key" do
      ch = build(:notification_channel, :pagerduty)
      expect(ch.pagerduty_integration_key).to eq("abc123")
    end

    it "#pagerduty_severity defaults to error when not set" do
      ch = build(:notification_channel, :pagerduty, config: { "integration_key" => "xyz" })
      expect(ch.pagerduty_severity).to eq("error")
    end
  end

  describe "#record_success!" do
    it "increments success_count and sets last_used_at" do
      channel = create(:notification_channel, success_count: 0)
      freeze_time do
        channel.record_success!
        expect(channel.reload.success_count).to eq(1)
        expect(channel.reload.last_used_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe "#record_failure!" do
    it "increments failure_count and sets last_used_at" do
      channel = create(:notification_channel, failure_count: 0)
      freeze_time do
        channel.record_failure!
        expect(channel.reload.failure_count).to eq(1)
        expect(channel.reload.last_used_at).to be_within(1.second).of(Time.current)
      end
    end
  end
end
