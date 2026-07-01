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
    org
    user
    sequence(:name) { |n| "Member Name #{n}" }
    roles { ["member"] }
  end

  factory :project do
    org
    sequence(:name) { |n| "Project #{n}" }
  end

  factory :participant do
    org
    project
    member
    roles { ["participant"] }
  end

  factory :day do
    org
    project
    date { Date.current }
  end

  factory :entry do
    day
    org { day.org }
    member
    log { "Working on test suite" }
    status { "doing" }
  end

  factory :session do
    user
    ip_address { "127.0.0.1" }
    user_agent { "RSpec Test User Agent" }
  end

  factory :integration do
    org
    integration_type { "notification" }
    service { "slack" }
    credentials { { "webhook_url" => "https://hooks.slack.com/services/123" } }
    template { "New entry by {{member_name}}: {{log}}" }
  end

  factory :project_integration do
    org
    project
    integration
  end

  factory :record_history do
    org_id { create(:org).id }
    done_by_admin { false }
    sequence(:user_id) { |n| SecureRandom.uuid }
    event { "created" }
    sequence(:record_id) { |n| SecureRandom.uuid }
    record_type { "Entry" }
    record_changes { {} }
  end
end
