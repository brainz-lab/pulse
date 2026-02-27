require "rails_helper"

RSpec.describe AlertRuleChannel, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:alert_rule) }
    it { is_expected.to belong_to(:notification_channel) }
  end

  describe "validations" do
    it "validates uniqueness of alert_rule_id scoped to notification_channel_id" do
      existing = create(:alert_rule_channel)
      duplicate = build(:alert_rule_channel,
                        alert_rule: existing.alert_rule,
                        notification_channel: existing.notification_channel)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:alert_rule_id]).to be_present
    end

    it "allows the same alert_rule with different channels" do
      rule = create(:alert_rule)
      channel1 = create(:notification_channel, project: rule.project)
      channel2 = create(:notification_channel, project: rule.project)
      create(:alert_rule_channel, alert_rule: rule, notification_channel: channel1)
      second = build(:alert_rule_channel, alert_rule: rule, notification_channel: channel2)
      expect(second).to be_valid
    end
  end
end
