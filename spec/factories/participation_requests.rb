FactoryBot.define do
  factory :participation_request do
    project
    member { association :member, org: project.org }
  end
end
