FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    password { "correct horse battery staple" } # 28 chars, within the 12..72 range

    trait :admin do
      admin { true }
    end
  end
end
