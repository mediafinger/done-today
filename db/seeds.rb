exit unless %w[development].include? AppConf.environment

require "faker"


puts "Deleting all uploaded files"

# FileUtils.rm_rf(Dir[Rails.root.join("tmp/storage/")]) # TODO: adapt to S3 storage for staging
# ActiveStorage::Blob.all.each(&:purge)

# clear DB before populating it

puts "Removing all records from the database"

(ActiveRecord::Base.connection.tables - %w[ar_internal_metadata schema_migrations]).each do |table|
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE;")
end


puts "Creating Orgs"

org = Org.create!(name: "zazu")


puts "Creating Users"

shared_user_params = { password: "foobar12345+" } # , verified: true }

andy = User.create!(email: "andy@example.com", name: "andy", **shared_user_params)
rinse = User.create!(email: "rinse@example.com", name: "rinse", **shared_user_params)


puts "Creating Memberships"

owner = Member.create!(user: andy, org:, roles: %w[owner member])
member = Member.create!(user: rinse, org:, roles: %w[member])


puts "Creating Projects"

project = Project.create!(name: "demo app", org:)


puts "Creating Participations"

Participant.create!(org:, project:, member: owner)
Participant.create!(org:, project:, member: member)


puts "Creating Days"

(1.week.ago.to_date..Date.tomorrow).to_a.each do |date|
  Day.create!(org:, project:, date:)
end


puts "Creating Entries"

Day.find_each do |day|
  Entry.create!(day:, org:, member: owner, log: Faker::Lorem.paragraph, status: Entry::STATES.sample)
  Entry.create!(day:, org:, member: member, log: Faker::Lorem.paragraph, status: Entry::STATES.sample)
end


puts "Creating Integrations"

reminder = Integration.create!(org:, integration_type: "reminder", service: "email", credentials: { access_token: "TODO" },
  template: "Please log what you have done today in {{project_name}}!")
notification = Integration.create!(org:, integration_type: "notification", service: "slack", credentials: { access_token: "TODO" },
  template: "Done on {{entry_day}} by {{member}}: {{entry_log}} [{{entry_status}}]!") # TODO: multiple entries per day


puts "Creating Project Integrations"

ProjectIntegration.create!(org:, project:, integration: reminder)
ProjectIntegration.create!(org:, project:, integration: notification)


puts "all done"
