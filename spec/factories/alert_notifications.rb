FactoryBot.define do
  factory :alert_notification do
    association :alert
    association :notification_channel
    status { "pending" }
    sent_at { nil }
    error_message { nil }

    trait :sent do
      status { "sent" }
      sent_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      error_message { "Connection refused" }
    end
  end
end
