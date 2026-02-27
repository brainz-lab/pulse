FactoryBot.define do
  factory :metric do
    association :project
    sequence(:name) { |n| "metric.#{n}" }
    kind { "gauge" }
    tags { {} }

    trait :counter do
      kind { "counter" }
    end

    trait :histogram do
      kind { "histogram" }
    end
  end
end
