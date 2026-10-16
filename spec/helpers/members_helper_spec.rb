require "rails_helper"

RSpec.describe MembersHelper do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:, name: "Website") }

  describe "#join_project_hint" do
    it "names the project's active leads" do
      create(:participant, :lead, project:, member: create(:member, org:, name: "Olivia"))
      create(:participant, :lead, project:, member: create(:member, org:, name: "Bob"))
      create(:participant, :lead, project:, member: create(:member, org:, name: "Gone")).member.archive!
      create(:participant, project:, member: create(:member, org:, name: "Paul"))

      expect(helper.join_project_hint(project.reload)).to eq("ask Bob or Olivia to join")
    end

    it "points to the org managers and owners without a project lead" do
      expect(helper.join_project_hint(project)).to eq("ask an org manager or owner to join")
    end
  end

  describe "#participant_roles_for" do
    it "offers guests no lead role" do
      expect(helper.participant_roles_for(build(:member, :guest))).to eq(%w[observer participant])
      expect(helper.participant_roles_for(build(:member))).to eq(%w[observer participant lead])
    end
  end

  describe "#invitation_role" do
    it "is the org role, or the guest's project with or without its role" do
      guest = build(:invitation, :guest, org:, project:, project_role: "observer")

      expect(helper.invitation_role(build(:invitation, :owner))).to eq("owner")
      expect(helper.invitation_role(guest)).to eq("guest in Website (observer)")
      expect(helper.invitation_role(guest, with_project_role: false)).to eq("guest in Website")
    end
  end

  describe "#participant_candidates" do
    it "groups members and guests, and leaves out empty groups" do
      ada = create(:member, org:, name: "Ada")
      gus = create(:member, :guest, org:, name: "Gus")

      expect(helper.participant_candidates([ ada, gus ]))
        .to eq({ "Members" => [ [ "Ada", ada.id ] ], "Guests (external)" => [ [ "Gus", gus.id ] ] })
      expect(helper.participant_candidates([ ada ])).to eq({ "Members" => [ [ "Ada", ada.id ] ] })
    end
  end
end
