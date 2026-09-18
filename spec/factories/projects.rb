FactoryBot.define do
  factory :project do
    org
    sequence(:name) { |n| "Project #{n}" }
  end
end
