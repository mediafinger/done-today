FactoryBot.define do
  factory :connection do
    user
    sequence(:name) { |n| "Laptop #{n}" }
  end

  factory :connection_grant do
    connection
    org
    access { "read" }

    trait :write do
      access { "write" }
    end
  end
end
