FactoryBot.define do
  factory :trace do
    association :project
    sequence(:trace_id) { |n| "trace-#{SecureRandom.hex(8)}-#{n}" }
    sequence(:name) { |n| "GET /endpoint/#{n}" }
    kind { "request" }
    started_at { Time.current }
    ended_at { nil }
    duration_ms { nil }
    status { 200 }
    error { false }

    trait :completed do
      started_at { 100.milliseconds.ago }
      ended_at { Time.current }
      duration_ms { 100.0 }
    end

    trait :slow do
      started_at { 2.seconds.ago }
      ended_at { Time.current }
      duration_ms { 2000.0 }
    end

    trait :error do
      error { true }
      error_class { "RuntimeError" }
      error_message { "something went wrong" }
      started_at { 50.milliseconds.ago }
      ended_at { Time.current }
      duration_ms { 50.0 }
    end

    trait :job do
      kind { "job" }
      sequence(:name) { |n| "ProcessOrderJob##{n}" }
    end

    trait :custom do
      kind { "custom" }
    end
  end
end
