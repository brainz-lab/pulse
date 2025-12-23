class AlertRuleChannel < ApplicationRecord
  belongs_to :alert_rule
  belongs_to :notification_channel

  validates :alert_rule_id, uniqueness: { scope: :notification_channel_id }
end
