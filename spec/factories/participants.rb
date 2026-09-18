FactoryBot.define do
  factory :participant do
    project
    # the member has to belong to the same org as the project, otherwise the
    # `readable_*` / `editable_*` scopes silently return nothing
    member { association :member, org: project.org }
    roles { %w[participant] }

    trait :owner do
      roles { %w[owner] }
    end

    trait :observer do
      roles { %w[observer] }
    end
  end
end
