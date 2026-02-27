FactoryBot.define do
  factory :metric_point do
    association :project
    association :metric
    timestamp { Time.current }
    value { 42.0 }
    tags { {} }
  end
end
