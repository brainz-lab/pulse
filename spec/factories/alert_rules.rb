FactoryBot.define do
  factory :alert_rule do
    association :project
    sequence(:name) { |n| "Alert Rule #{n}" }
    metric_type { "error_rate" }
    operator { "gt" }
    threshold { 5.0 }
    aggregation { "avg" }
    window_minutes { 5 }
    cooldown_minutes { 15 }
    severity { "warning" }
    status { "ok" }
    enabled { true }
    last_triggered_at { nil }

    trait :critical do
      severity { "critical" }
      metric_type { "apdex" }
      operator { "lt" }
      threshold { 0.7 }
    end

    trait :alerting do
      status { "alerting" }
      last_triggered_at { 1.minute.ago }
    end

    trait :in_cooldown do
      last_triggered_at { 5.minutes.ago }
      cooldown_minutes { 15 }
    end

    trait :custom_metric do
      metric_type { "custom" }
      metric_name { "orders.failed" }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
