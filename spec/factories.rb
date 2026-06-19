FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User Name #{n}" }
    password { "password123456" }
    password_confirmation { "password123456" }
  end

  factory :org do
    sequence(:name) { |n| "Organization #{n}" }
  end

  factory :member do
    association :org
    association :user
    sequence(:name) { |n| "Member Name #{n}" }
    roles { ["member"] }
  end

  factory :project do
    association :org
    sequence(:name) { |n| "Project #{n}" }
  end

  factory :participant do
    association :org
    association :project
    association :member
    roles { ["participant"] }
  end

  factory :day do
    association :org
    association :project
    date { Date.current }
  end

  factory :entry do
    association :day
    org { day.org }
    association :member
    log { "Working on test suite" }
    status { "doing" }
  end

  factory :session do
    association :user
    ip_address { "127.0.0.1" }
    user_agent { "RSpec Test User Agent" }
  end

  factory :integration do
    association :org
    integration_type { "notification" }
    service { "slack" }
    credentials { { "webhook_url" => "https://hooks.slack.com/services/123" } }
    template { "New entry by {{member_name}}: {{log}}" }
  end

  factory :project_integration do
    association :org
    association :project
    association :integration
  end

  factory :record_history do
    association :org
    done_by_admin { false }
    sequence(:user_id) { |n| SecureRandom.uuid }
    event { "created" }
    sequence(:record_id) { |n| SecureRandom.uuid }
    record_type { "Entry" }
    changes { {} }
  end
end
