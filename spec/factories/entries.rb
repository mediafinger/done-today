FactoryBot.define do
  factory :entry do
    day
    member { association :member, org: day.org }
    log { "Wrote some code" }
    status { "doing" }

    trait :todo do
      status { "todo" }
    end

    trait :done do
      status { "done" }
    end
  end
end
