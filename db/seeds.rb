exit unless %w[development].include? AppConf.environment

require "faker"

# This file TRUNCATEs every table before inserting anything, so `bin/rails db:seed`
#   destroys whatever is in the development database -- which is where the real
#   day-to-day logging happens. That has cost real data once.
#
# It now refuses to run against a database that already holds records unless
#   SEED_FORCE=1 is set explicitly.
#
existing_records = Org.count + User.count + Entry.count

if existing_records.positive? && ENV["SEED_FORCE"] != "1"
  abort <<~REFUSED

    Refusing to seed: the database holds #{existing_records} records, and seeding truncates every table.

      back it up first:    rake db:backup
      check it restores:   rake db:backup:verify
      then, on purpose:    SEED_FORCE=1 bin/rails db:seed

  REFUSED
end

puts "Deleting all uploaded files"

# FileUtils.rm_rf(Dir[Rails.root.join("tmp/storage/")]) # TODO: adapt to S3 storage for staging
# ActiveStorage::Blob.all.each(&:purge)

# clear DB before populating it

# puts "Removing all records from the database"

# (ActiveRecord::Base.connection.tables - %w[ar_internal_metadata schema_migrations]).each do |table|
#   ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE;")
# end


puts "Creating Orgs"

org = Org.create!(name: "Demo")
lyvo = Org.create!(name: "Lyvo")


puts "Creating Users"

shared_user_params = { password: "foobar1234" } # , verified: true }

andy = User.create!(email: "andy@example.com", name: "andy", **shared_user_params)
doro = User.create!(email: "doro@example.com", name: "doro", **shared_user_params)


puts "Creating Memberships"

owner = Member.create!(user: andy, org:, roles: %w[owner member])
owner = Member.create!(user: andy, org: lyvo, roles: %w[owner member])
member = Member.create!(user: doro, org:, roles: %w[member])


puts "Creating Projects"

project = Project.create!(name: "example project", org:)
project_lvyo = Project.create!(name: "2026 V1", org: lyvo)


puts "Creating Participations"

Participant.create!(org:, project:, member: owner)
Participant.create!(org:, project:, member: member)
Participant.create!(org: lyvo, project: project_lvyo, member: owner)


puts "Creating Days"

(1.week.ago.to_date..Date.tomorrow).to_a.each do |date|
  Day.create!(org:, project:, date:)
  Day.create!(org: lyvo, project: project_lvyo, date:)
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
