require "rails_helper"

RSpec.describe AlertRule, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:alert_rule_channels).dependent(:destroy) }
    it { is_expected.to have_many(:notification_channels).through(:alert_rule_channels) }
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:metric_type) }
    it { is_expected.to validate_inclusion_of(:metric_type).in_array(described_class::METRIC_TYPES) }
    it { is_expected.to validate_presence_of(:operator) }
    it { is_expected.to validate_inclusion_of(:operator).in_array(described_class::OPERATORS) }
    it { is_expected.to validate_presence_of(:threshold) }
    it { is_expected.to validate_numericality_of(:threshold) }
    it { is_expected.to validate_inclusion_of(:aggregation).in_array(described_class::AGGREGATIONS) }
    it { is_expected.to validate_numericality_of(:window_minutes).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:cooldown_minutes).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_inclusion_of(:severity).in_array(described_class::SEVERITIES) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }

    context "when metric_type is custom" do
      subject { build(:alert_rule, :custom_metric) }

      it { is_expected.to validate_presence_of(:metric_name) }
    end
  end

  describe "scopes" do
    describe ".enabled" do
      it "returns only enabled rules" do
        enabled = create(:alert_rule, enabled: true)
        disabled = create(:alert_rule, :disabled)
        expect(described_class.enabled).to include(enabled)
        expect(described_class.enabled).not_to include(disabled)
      end
    end

    describe ".alerting" do
      it "returns only rules with alerting status" do
        alerting = create(:alert_rule, :alerting)
        ok_rule = create(:alert_rule, status: "ok")
        expect(described_class.alerting).to include(alerting)
        expect(described_class.alerting).not_to include(ok_rule)
      end
    end

    describe ".by_metric_type" do
      it "filters by metric type" do
        error_rule = create(:alert_rule, metric_type: "error_rate")
        apdex_rule = create(:alert_rule, metric_type: "apdex", operator: "lt", threshold: 0.7)
        expect(described_class.by_metric_type("error_rate")).to include(error_rule)
        expect(described_class.by_metric_type("error_rate")).not_to include(apdex_rule)
      end
    end
  end

  describe "#custom_metric?" do
    it "returns true when metric_type is custom" do
      rule = build(:alert_rule, :custom_metric)
      expect(rule.custom_metric?).to be true
    end

    it "returns false for non-custom metric types" do
      rule = build(:alert_rule, metric_type: "error_rate")
      expect(rule.custom_metric?).to be false
    end
  end

  describe "#condition_met?" do
    subject(:rule) { build(:alert_rule, operator: "gt", threshold: 100) }

    it "returns true when value exceeds threshold (gt)" do
      expect(rule.condition_met?(150)).to be true
    end

    it "returns false when value is below threshold (gt)" do
      expect(rule.condition_met?(50)).to be false
    end

    it "handles gte operator" do
      rule = build(:alert_rule, operator: "gte", threshold: 100)
      expect(rule.condition_met?(100)).to be true
      expect(rule.condition_met?(99)).to be false
    end

    it "handles lt operator" do
      rule = build(:alert_rule, operator: "lt", threshold: 0.7, metric_type: "apdex")
      expect(rule.condition_met?(0.6)).to be true
      expect(rule.condition_met?(0.8)).to be false
    end

    it "handles lte operator" do
      rule = build(:alert_rule, operator: "lte", threshold: 0.7, metric_type: "apdex")
      expect(rule.condition_met?(0.7)).to be true
      expect(rule.condition_met?(0.8)).to be false
    end

    it "handles eq operator" do
      rule = build(:alert_rule, operator: "eq", threshold: 0)
      expect(rule.condition_met?(0)).to be true
      expect(rule.condition_met?(1)).to be false
    end
  end

  describe "#in_cooldown?" do
    it "returns false when never triggered" do
      rule = build(:alert_rule, last_triggered_at: nil)
      expect(rule.in_cooldown?).to be false
    end

    it "returns true when last triggered within cooldown window" do
      rule = build(:alert_rule, :in_cooldown)
      expect(rule.in_cooldown?).to be true
    end

    it "returns false when last triggered outside cooldown window" do
      rule = build(:alert_rule, last_triggered_at: 30.minutes.ago, cooldown_minutes: 15)
      expect(rule.in_cooldown?).to be false
    end
  end

  describe "#trigger!" do
    let(:rule) { create(:alert_rule, status: "ok", threshold: 5.0) }

    it "creates a firing alert" do
      expect { rule.trigger!(value: 8.5) }.to change(Alert, :count).by(1)
    end

    it "updates status to alerting" do
      rule.trigger!(value: 8.5)
      expect(rule.reload.status).to eq("alerting")
    end

    it "sets last_triggered_at" do
      freeze_time do
        rule.trigger!(value: 8.5)
        expect(rule.reload.last_triggered_at).to be_within(1.second).of(Time.current)
      end
    end

    it "does nothing when in cooldown" do
      rule.update!(last_triggered_at: 5.minutes.ago, cooldown_minutes: 15)
      expect { rule.trigger!(value: 8.5) }.not_to change(Alert, :count)
    end
  end

  describe "#resolve!" do
    it "resolves all firing alerts and resets status to ok" do
      rule = create(:alert_rule, :alerting)
      firing_alert = create(:alert, alert_rule: rule, project: rule.project, status: "firing")

      rule.resolve!

      expect(rule.reload.status).to eq("ok")
      expect(firing_alert.reload.status).to eq("resolved")
      expect(firing_alert.reload.resolved_at).not_to be_nil
    end

    it "does nothing when status is not alerting" do
      rule = create(:alert_rule, status: "ok")
      expect { rule.resolve! }.not_to change(rule, :status)
    end
  end

  describe "#human_condition" do
    it "formats error_rate condition correctly" do
      rule = build(:alert_rule, metric_type: "error_rate", operator: "gt", threshold: 5)
      expect(rule.human_condition).to eq("Error rate > 5%")
    end

    it "formats apdex condition correctly" do
      rule = build(:alert_rule, metric_type: "apdex", operator: "lt", threshold: 0.7)
      expect(rule.human_condition).to eq("Apdex < 0.7")
    end

    it "formats response_time condition correctly" do
      rule = build(:alert_rule, metric_type: "response_time", operator: "gt", threshold: 500)
      expect(rule.human_condition).to eq("Response time > 500ms")
    end

    it "uses metric_name for custom metric" do
      rule = build(:alert_rule, :custom_metric, operator: "gt", threshold: 10)
      expect(rule.human_condition).to eq("orders.failed > 10")
    end
  end
end
