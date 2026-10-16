require "rails_helper"
require Rails.root.join("db/migrate/20261017120810_rename_project_owner_to_lead")

RSpec.describe RenameProjectOwnerToLead do
  let(:project) { create(:project) }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  def migrate(direction)
    described_class.new.migrate(direction)
  end

  def participant(name, roles)
    create(:participant, project:, member: create(:member, org: project.org, name:)).tap do
      it.update_columns(roles:) # rubocop:disable Rails/SkipsModelValidations -- the old role does not validate
    end
  end

  def roles
    Participant.joins(:member).order("members.name").pluck("members.name", :roles)
  end

  before do
    migrate(:down)

    participant("Lead", %w[owner])
    participant("Lead and participant", %w[participant owner])
    participant("Participant", %w[participant])
    participant("Observer", %w[observer])
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
