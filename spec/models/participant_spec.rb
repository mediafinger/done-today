require "rails_helper"

RSpec.describe Participant do
  describe "associations" do
    it "has expected associations" do
      org_assoc = described_class.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)

      proj_assoc = described_class.reflect_on_association(:project)
      expect(proj_assoc.macro).to eq(:belongs_to)
      expect(proj_assoc.options[:inverse_of]).to eq(:participants)

      memb_assoc = described_class.reflect_on_association(:member)
      expect(memb_assoc.macro).to eq(:belongs_to)
      expect(memb_assoc.options[:inverse_of]).to eq(:participations)
    end
  end

  describe "validations" do
    it "validates inclusion of roles" do
      participant = build(:participant, roles: ["invalid_role"])
      expect(participant).not_to be_valid
    end
  end

  describe "callbacks" do
    it "sets the org from project's org on validation" do
      org = create(:org)
      project = create(:project, org: org)
      participant = build(:participant, project: project, org: nil)
      participant.valid?
      expect(participant.org).to eq(org)
    end
  end

  describe "scopes" do
    let!(:participant1) { create(:participant, roles: ["owner"]) }
    let!(:participant2) { create(:participant, roles: ["observer"]) }

    it "filters by includes_a_role_of" do
      expect(described_class.includes_a_role_of(["owner"])).to include(participant1)
      expect(described_class.includes_a_role_of(["owner"])).not_to include(participant2)
    end
  end

  describe "#editable_entries" do
    let(:org) { create(:org) }
    let(:project) { create(:project, org: org) }
    let(:member) { create(:member, org: org) }
    let(:day) { create(:day, org: org, project: project) }
    let!(:entry) { create(:entry, day: day, org: org, member: member) }

    it "allows owner to edit all project entries" do
      participant = create(:participant, org: org, project: project, member: member, roles: ["owner"])
      expect(participant.editable_entries).to include(entry)
    end

    it "allows participant to edit only their own entries" do
      participant = create(:participant, org: org, project: project, member: member, roles: ["participant"])
      expect(participant.editable_entries).to include(entry)

      other_member = create(:member, org: org)
      participant_other = create(:participant, org: org, project: project, member: other_member, roles: ["participant"])
      expect(participant_other.editable_entries).not_to include(entry)
    end
  end
end
