require "rails_helper"

RSpec.describe Member do
  let(:org) { create(:org) }
  let!(:joined_project) { create(:project, org:) }
  let!(:other_project) { create(:project, org:) }

  describe "#readable_projects" do
    it "returns only the projects a plain member participates in" do
      member = create(:member, org:)
      create(:participant, project: joined_project, member:)

      expect(member.readable_projects).to contain_exactly(joined_project)
    end

    it "returns every project of the org for an owner" do
      owner = create(:member, :owner, org:)

      expect(owner.readable_projects).to contain_exactly(joined_project, other_project)
    end

    it "returns nothing for a member without roles" do
      member = create(:member, org:)
      member.roles = [] # roles are validated, so this branch is only reachable in memory

      expect(member.readable_projects).to be_empty
    end

    it "narrows the result by the given relation" do
      member = create(:member, org:)
      create(:participant, project: joined_project, member:)

      expect(member.readable_projects(relation: Project.where(id: other_project.id))).to be_empty
    end
  end

  describe "#editable_projects" do
    it "returns the projects the member participates in" do
      member = create(:member, org:)
      create(:participant, project: joined_project, member:)

      expect(member.editable_projects).to contain_exactly(joined_project)
    end

    it "excludes projects the member only observes" do
      member = create(:member, org:)
      create(:participant, :observer, project: joined_project, member:)

      expect(member.editable_projects).to be_empty
    end
  end

  describe "#exportable_projects" do
    it "returns every project of the org for an org owner" do
      owner = create(:member, :owner, org:)

      expect(owner.exportable_projects).to contain_exactly(joined_project, other_project)
    end

    it "returns the projects a plain member owns as a participant" do
      member = create(:member, org:)
      create(:participant, :owner, project: joined_project, member:)
      create(:participant, project: other_project, member:)

      expect(member.exportable_projects).to contain_exactly(joined_project)
    end

    it "returns nothing for a member who only participates" do
      member = create(:member, org:)
      create(:participant, project: joined_project, member:)

      expect(member.exportable_projects).to be_empty
    end

    it "returns nothing for a member without roles" do
      member = create(:member, org:)
      member.roles = [] # roles are validated, so this branch is only reachable in memory

      expect(member.exportable_projects).to be_empty
    end

    it "narrows the result by the given relation" do
      owner = create(:member, :owner, org:)

      expect(owner.exportable_projects(relation: joined_project)).to contain_exactly(joined_project)
    end
  end

  describe "#readable_entries" do
    it "returns the entries of the member's projects" do
      member = create(:member, org:)
      create(:participant, project: joined_project, member:)
      mine = create(:entry, day: create(:day, project: joined_project), member:)
      create(:entry, day: create(:day, project: other_project), member: create(:member, org:))

      expect(member.readable_entries).to contain_exactly(mine)
    end
  end

  describe "roles" do
    it "adds and removes roles without duplicating them" do
      member = create(:member, org:)

      member.add_role!("owner")
      member.add_role!("owner")

      expect(member.reload.roles).to contain_exactly("member", "owner")

      member.delete_role!("owner")

      expect(member.reload.roles).to contain_exactly("member")
    end

    it "refuses an unknown role" do
      member = create(:member, org:)

      member.add_role("wizard")

      expect(member.errors[:roles]).to be_present
    end
  end
end
