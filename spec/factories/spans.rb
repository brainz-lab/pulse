FactoryBot.define do
  factory :span do
    association :trace
    association :project
    sequence(:span_id) { |n| "span-#{SecureRandom.hex(8)}-#{n}" }
    sequence(:name) { |n| "operation #{n}" }
    kind { "db" }
    started_at { Time.current }
    ended_at { 10.milliseconds.from_now }
    duration_ms { 10.0 }
    data { {} }
    error { false }

    trait :http do
      kind { "http" }
      data { { "method" => "GET", "url" => "https://api.example.com/users" } }
    end

    trait :cache do
      kind { "cache" }
      data { { "hit" => true, "key" => "users/1" } }
    end

    trait :browser_lcp do
      kind { "browser.lcp" }
      data { { "rating" => "good" } }
      duration_ms { 1200.0 }
    end

    trait :slow do
      duration_ms { 500.0 }
    end
  end
end
