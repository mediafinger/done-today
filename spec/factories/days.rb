FactoryBot.define do
  factory :day do
    project
    date { Date.current }
  end
end
