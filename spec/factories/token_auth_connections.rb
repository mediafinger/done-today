FactoryBot.define do
  factory :token_auth_connection, class: "TokenAuth::Connection" do
    user
    sequence(:name) { |n| "Laptop #{n}" }
  end

  factory :token_auth_connection_grant, class: "TokenAuth::ConnectionGrant" do
    connection factory: :token_auth_connection
    org
    access { "read" }

    trait :write do
      access { "write" }
    end
  end
end
