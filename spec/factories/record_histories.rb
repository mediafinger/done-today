FactoryBot.define do
  factory :record_history do
    org
    event { "created" }
    record_id { SecureRandom.uuid }
    record_type { "Entry" }
    record_changes { { "log" => [ nil, "Wrote some code" ] } }
    user_id { SecureRandom.uuid }
  end
end
