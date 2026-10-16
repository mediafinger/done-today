FactoryBot.define do
  factory :participant do
    project
    # the member has to belong to the same org as the project, otherwise the
    # policy scopes silently return nothing
    member { association :member, org: project.org }
    role { "participant" }

    trait :lead do
      role { "lead" }
    end

    trait :observer do
      role { "observer" }
    end
  end
end
