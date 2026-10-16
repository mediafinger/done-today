require "rails_helper"
require Rails.root.join("db/migrate/20261017120820_replace_participant_roles_with_role")

RSpec.describe ReplaceParticipantRolesWithRole do
  let(:connection) { ActiveRecord::Base.connection }
  let(:project) { create(:project) }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  # the DDL runs inside the example's transaction and is rolled back with it
  after { Participant.reset_column_information }

  def migrate(direction)
    described_class.new.migrate(direction)
    Participant.reset_column_information
  end

  def insert_participant(name, roles)
    member = create(:member, org: project.org, name:)

    connection.execute(<<~SQL)
      INSERT INTO participants (org_id, project_id, member_id, roles, created_at, updated_at)
      VALUES (#{connection.quote(project.org_id)}, #{connection.quote(project.id)}, #{connection.quote(member.id)},
              ARRAY[#{roles.map { connection.quote(it) }.join(", ")}]::text[], now(), now())
    SQL
  end

  def rows(column)
    connection.select_all(<<~SQL).cast_values
      SELECT members.name, participants.#{column} FROM participants
      JOIN members ON members.id = participants.member_id ORDER BY members.name
    SQL
  end

  before do
    project
    migrate(:down)

    insert_participant("Lead", %w[lead])
    insert_participant("Lead and participant", %w[participant lead])
    insert_participant("Observer", %w[observer])
    insert_participant("Observer and participant", %w[observer participant])
    insert_participant("Participant", %w[participant])
  end

  it "keeps the strongest of the roles" do
    migrate(:up)

    expect(rows(:role)).to eq(
      [ [ "Lead", "lead" ], [ "Lead and participant", "lead" ], [ "Observer", "observer" ],
        [ "Observer and participant", "participant" ], [ "Participant", "participant" ] ]
    )
  end

  it "migrates back to the roles arrays, one role each" do
    migrate(:up)
    migrate(:down)

    expect(rows(:roles)).to eq(
      [ [ "Lead", %w[lead] ], [ "Lead and participant", %w[lead] ], [ "Observer", %w[observer] ],
        [ "Observer and participant", %w[participant] ], [ "Participant", %w[participant] ] ]
    )
  end
end
