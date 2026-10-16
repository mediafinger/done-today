FactoryBot.define do
  factory :invitation do
    org
    sequence(:email) { |n| "invitee#{n}@example.com" }
    role { "member" }

    trait :guest do
      role { "guest" }
      project { association :project, org: }
      project_role { "participant" }
    end

    trait :owner do
      role { "owner" }
    end
  end
end
