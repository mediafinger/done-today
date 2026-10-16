FactoryBot.define do
  factory :invitation do
    org
    sequence(:email) { |n| "invitee#{n}@example.com" }
    role { "member" }

    trait :owner do
      role { "owner" }
    end
  end
end
