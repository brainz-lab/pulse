FactoryBot.define do
  factory :alert do
    association :project
    association :alert_rule
    status { "firing" }
    severity { "warning" }
    metric_type { "error_rate" }
    operator { "gt" }
    threshold { 5.0 }
    value { 8.5 }
    triggered_at { Time.current }
    resolved_at { nil }

    trait :resolved do
      status { "resolved" }
      resolved_at { 10.minutes.from_now }
    end

    trait :critical do
      severity { "critical" }
    end
  end
end
