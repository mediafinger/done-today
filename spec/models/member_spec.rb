require "rails_helper"

RSpec.describe Member do
  describe "associations" do
    it "has many and belongs to associations" do
      org_assoc = described_class.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)
      expect(org_assoc.options[:inverse_of]).to eq(:members)

      user_assoc = described_class.reflect_on_association(:user)
      expect(user_assoc.macro).to eq(:belongs_to)
      expect(user_assoc.options[:inverse_of]).to eq(:memberships)

      entries_assoc = described_class.reflect_on_association(:entries)
      expect(entries_assoc.macro).to eq(:has_many)
      expect(entries_assoc.options[:dependent]).to eq(:destroy)

      part_assoc = described_class.reflect_on_association(:participations)
      expect(part_assoc.macro).to eq(:has_many)
      expect(part_assoc.options[:class_name]).to eq("Participant")
      expect(part_assoc.options[:inverse_of]).to eq(:member)
      expect(part_assoc.options[:dependent]).to eq(:destroy)

      proj_assoc = described_class.reflect_on_association(:projects)
      expect(proj_assoc.macro).to eq(:has_many)
      expect(proj_assoc.options[:through]).to eq(:participations)
    end
  end

  describe "validations" do
    it "validates presence of name" do
      user = build(:user, name: "")
      member = build(:member, user: user, name: nil)
      expect(member).not_to be_valid
    end

    it "validates presence and inclusion of roles" do
      member = build(:member, roles: [])
      expect(member).not_to be_valid

      member = build(:member, roles: ["invalid_role"])
      expect(member).not_to be_valid
    end
  end

  describe "callbacks" do
    it "sets the member name to the user's name if blank before validation on create" do
      user = create(:user, name: "Alice Smith")
      member = build(:member, user: user, name: nil)
      member.valid?
      expect(member.name).to eq("Alice Smith")
    end
  end

  describe "scopes" do
    let!(:org) { create(:org) }
    let!(:owner_member) { create(:member, org: org, roles: ["owner"]) }
    let!(:regular_member) { create(:member, org: org, roles: ["member"]) }

    it "filters by includes_a_role_of" do
      expect(described_class.includes_a_role_of(["owner"])).to include(owner_member)
      expect(described_class.includes_a_role_of(["owner"])).not_to include(regular_member)
    end

    it "filters by includes_all_roles" do
      expect(described_class.includes_all_roles(["owner"])).to include(owner_member)
      expect(described_class.includes_all_roles(["owner"])).not_to include(regular_member)
    end
  end

  describe "role management methods" do
    let(:member) { create(:member, roles: ["member"]) }

    it "adds role and saves" do
      member.add_role!("owner")
      expect(member.reload.roles).to contain_exactly("member", "owner")
    end

    it "adds role to array without saving" do
      member.add_role("owner")
      expect(member.roles).to contain_exactly("member", "owner")
      expect(member).to be_changed
    end

    it "deletes role and saves" do
      member.add_role!("owner")
      member.delete_role!("member")
      expect(member.reload.roles).to eq(["owner"])
    end

    it "deletes role without saving" do
      member.add_role!("owner")
      member.delete_role("member")
      expect(member.roles).to eq(["owner"])
      expect(member).to be_changed
    end
  end

  describe "#editable_projects" do
    let(:org) { create(:org) }
    let(:member) { create(:member, org: org, roles: ["member"]) }
    let(:project) { create(:project, org: org) }

    it "returns none for member with no participations" do
      expect(member.editable_projects).to be_empty
    end

    it "returns project if member has participant role in project" do
      create(:participant, org: org, project: project, member: member, roles: ["participant"])
      expect(member.editable_projects).to include(project)
    end
  end

  describe "#readable_projects" do
    let(:org) { create(:org) }
    let(:owner) { create(:member, org: org, roles: ["owner"]) }
    let(:project) { create(:project, org: org) }

    it "returns all projects for owners" do
      expect(owner.readable_projects).to include(project)
    end
  end
end
