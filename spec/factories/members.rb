FactoryBot.define do
  factory :member do
    org
    user
    role { "member" }

    trait :guest do
      role { "guest" }
    end

    trait :manager do
      role { "manager" }
    end

    trait :owner do
      role { "owner" }
    end
  end
end
