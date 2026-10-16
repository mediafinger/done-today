require "rails_helper"

RSpec.describe EntryPolicy do
  let(:project) { create(:project) }
  let(:day) { create(:day, project:) }
  let!(:colleagues_entry) { create(:entry, day:, member: create(:participant, project:).member) }

  def member_with(org_roles:, project_roles:)
    create(:member, org: project.org, roles: org_roles).tap do |member|
      create(:participant, project:, member:, roles: project_roles) if project_roles
    end
  end

  # org roles, project roles => may update own entry, may update a colleague's entry
  {
    [ %w[member], nil ] => [ false, false ],
    [ %w[member], %w[observer] ] => [ false, false ],
    [ %w[member], %w[participant] ] => [ true, false ],
    [ %w[member], %w[owner] ] => [ true, true ],
    [ %w[member owner], nil ] => [ false, false ],
    [ %w[member owner], %w[observer] ] => [ false, false ],
    [ %w[member owner], %w[participant] ] => [ true, false ],
    [ %w[member owner], %w[owner] ] => [ true, true ]
  }.each do |(org_roles, project_roles), (own, colleagues)|
    context "with org roles #{org_roles} and project roles #{project_roles.inspect}" do
      let(:member) { member_with(org_roles:, project_roles:) }
      # an observer or ex-participant may still have entries from earlier
      let!(:own_entry) { create(:entry, day:, member:) }

      it { expect(described_class.new(member, own_entry).update?).to be(own) }
      it { expect(described_class.new(member, colleagues_entry).update?).to be(colleagues) }

      it "lists exactly the entries it may update as editable" do
        expected = [ (own_entry if own), (colleagues_entry if colleagues) ].compact

        expect(described_class.editable(member)).to match_array(expected)
      end

      it "lists the entries as readable exactly when the project may be shown" do
        readable = ProjectPolicy.new(member, project).show?

        expect(described_class.readable(member).include?(colleagues_entry)).to be(readable)
      end
    end
  end

  it "does not let a project owner edit entries of another project" do
    owner = member_with(org_roles: %w[member], project_roles: %w[owner])
    elsewhere = create(:entry, day: create(:day, project: create(:project, org: project.org)))

    expect(described_class.new(owner, elsewhere).update?).to be(false)
    expect(described_class.editable(owner)).not_to include(elsewhere)
  end

  it "lets an archived project owner neither read nor edit, not even their own entries" do
    owner = member_with(org_roles: %w[member], project_roles: %w[owner])
    own_entry = create(:entry, day:, member: owner)
    owner.archive!

    expect(described_class.new(owner, own_entry).update?).to be(false)
    expect(described_class.editable(owner)).to be_empty
    expect(described_class.readable(owner)).to be_empty
  end

  it "lets nobody edit the entries of an archived project" do
    owner = member_with(org_roles: %w[member owner], project_roles: %w[owner])
    own_entry = create(:entry, day:, member: owner)
    project.archive!

    expect(described_class.new(owner, own_entry).update?).to be(false)
    expect(described_class.new(owner, colleagues_entry).update?).to be(false)
    expect(described_class.editable(owner)).to be_empty
    expect(described_class.readable(owner)).to include(own_entry, colleagues_entry)
  end
end
