FactoryBot.define do
  factory :notification_channel do
    association :project
    sequence(:name) { |n| "Channel #{n}" }
    kind { "webhook" }
    config { { "url" => "https://hooks.example.com/alert" } }
    enabled { true }
    success_count { 0 }
    failure_count { 0 }

    trait :email do
      kind { "email" }
      config { { "addresses" => ["ops@example.com"] } }
    end

    trait :slack do
      kind { "slack" }
      config { { "webhook_url" => "https://hooks.slack.com/services/T000/B000/xxx", "channel" => "#alerts" } }
    end

    trait :pagerduty do
      kind { "pagerduty" }
      config { { "integration_key" => "abc123", "severity" => "critical" } }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
