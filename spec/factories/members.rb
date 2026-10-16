FactoryBot.define do
  factory :member do
    org
    user
    role { "member" }

    trait :owner do
      role { "owner" }
    end
  end
end
