FactoryBot.define do
  factory :member do
    org
    user
    roles { %w[member] }

    trait :owner do
      roles { %w[member owner] }
    end
  end
end
