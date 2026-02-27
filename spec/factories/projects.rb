FactoryBot.define do
  factory :project do
    sequence(:platform_project_id) { |n| SecureRandom.uuid }
    sequence(:name) { |n| "Project #{n}" }
    environment { "live" }
    settings { {} }
    archived_at { nil }

    trait :archived do
      archived_at { 1.day.ago }
    end

    trait :with_apdex_t do
      settings { { "apdex_t" => 1.0 } }
    end
  end
end
