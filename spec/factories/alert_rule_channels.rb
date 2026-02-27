FactoryBot.define do
  factory :alert_rule_channel do
    association :alert_rule
    association :notification_channel
  end
end
