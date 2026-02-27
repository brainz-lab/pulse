FactoryBot.define do
  factory :aggregated_metric do
    association :project
    sequence(:name) { |n| "metric.#{n}" }
    bucket { Time.current.beginning_of_hour }
    granularity { "hour" }
    avg { 100.0 }
    min { 50.0 }
    max { 200.0 }
    count { 10 }

    trait :minute do
      granularity { "minute" }
      bucket { Time.current.beginning_of_minute }
    end

    trait :day do
      granularity { "day" }
      bucket { Time.current.beginning_of_day }
    end
  end
end
