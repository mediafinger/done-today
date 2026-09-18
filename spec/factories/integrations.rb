FactoryBot.define do
  factory :integration do
    org
    integration_type { "reminder" }
    service { "email" }
    credentials { { access_token: "test-token" } }
    template { "Please log what you have done today in {{project_name}}!" }
  end

  factory :project_integration do
    project
    integration { association :integration, org: project.org }
  end
end
