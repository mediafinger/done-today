require "rails_helper"
require Rails.root.join("db/migrate/20261017120810_rename_project_owner_to_lead")
require Rails.root.join("db/migrate/20261017120820_replace_participant_roles_with_role")

RSpec.describe RenameProjectOwnerToLead do
  let(:connection) { ActiveRecord::Base.connection }
  let(:project) { create(:project) }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  # the DDL runs inside the example's transaction and is rolled back with it
  after { Participant.reset_column_information }

  def migrate(direction)
    described_class.new.migrate(direction)
  end

  def insert_participant(name, roles)
    member = create(:member, org: project.org, name:)

    connection.execute(<<~SQL)
      INSERT INTO participants (org_id, project_id, member_id, roles, created_at, updated_at)
      VALUES (#{connection.quote(project.org_id)}, #{connection.quote(project.id)}, #{connection.quote(member.id)},
              ARRAY[#{roles.map { connection.quote(it) }.join(", ")}]::text[], now(), now())
    SQL
  end

  def roles
    connection.select_all(<<~SQL).cast_values
      SELECT members.name, participants.roles FROM participants
      JOIN members ON members.id = participants.member_id ORDER BY members.name
    SQL
  end

  before do
    project
    # back to the roles arrays this migration ran on
    ReplaceParticipantRolesWithRole.new.migrate(:down)
    migrate(:down)

    insert_participant("Lead", %w[owner])
    insert_participant("Lead and participant", %w[participant owner])
    insert_participant("Participant", %w[participant])
    insert_participant("Observer", %w[observer])
  end

  it "renames the project role owner to lead, leaving the other roles" do
    migrate(:up)

    expect(roles).to eq(
      [ [ "Lead", %w[lead] ], [ "Lead and participant", %w[participant lead] ],
        [ "Observer", %w[observer] ], [ "Participant", %w[participant] ] ]
    )
  end

  it "migrates back to owner" do
    migrate(:up)
    migrate(:down)

    expect(roles).to eq(
      [ [ "Lead", %w[owner] ], [ "Lead and participant", %w[participant owner] ],
        [ "Observer", %w[observer] ], [ "Participant", %w[participant] ] ]
    )
  end
end
