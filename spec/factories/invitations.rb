FactoryBot.define do
  factory :invitation do
    org
    sequence(:email) { |n| "invitee#{n}@example.com" }
    roles { %w[member] }

    trait :owner do
      roles { %w[member owner] }
    end
  end
end
