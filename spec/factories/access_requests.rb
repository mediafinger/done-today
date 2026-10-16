FactoryBot.define do
  factory :access_request do
    project
    member { association :member, org: project.org }
  end
end
