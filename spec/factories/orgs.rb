FactoryBot.define do
  factory :org do
    sequence(:name) { |n| "Org #{n}" }
  end
end
