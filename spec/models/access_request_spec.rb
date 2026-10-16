require "rails_helper"

RSpec.describe AccessRequest do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:lead) { create(:participant, :lead, project:).member }

  def request_access(**attributes)
    described_class.create!(project:, member:, **attributes)
  end

  it "is pending, in the project's org" do
    access_request = request_access

    expect(access_request).to be_pending
    expect(access_request.org).to eq(org)
  end

  it "allows one pending request per member and project" do
    request_access

    duplicate = described_class.new(project:, member:)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:base]).to include("You already asked to join #{project.name}")
  end

  it "allows asking again after a decline" do
    request_access.decline!(by: lead)

    expect(described_class.new(project:, member:)).to be_valid
  end

  it "has to be a member of the project's org" do
    stranger = described_class.new(project:, member: create(:member))

    expect(stranger).not_to be_valid
    expect(stranger.errors[:member]).to be_present
  end

  it "keeps the message short and drops a blank one" do
    expect(described_class.new(project:, member:, message: "x" * 501)).not_to be_valid
    expect(request_access(message: "  ").message).to be_nil
  end

  describe "#grant!" do
    it "adds the member with the role and records the decision" do
      access_request = request_access

      participant = access_request.grant!(by: lead, role: "observer")

      expect(participant).to be_persisted
      expect(participant.role).to eq("observer")
      expect(access_request.reload).to have_attributes(status: "granted", decided_by: lead)
      expect(access_request.decided_at).to be_present
    end

    it "changes nothing when the role does not fit" do
      access_request = request_access

      participant = access_request.grant!(by: lead, role: "admin")

      expect(participant).not_to be_persisted
      expect(access_request.reload).to be_pending
    end
  end

  describe "#decline!" do
    it "records the decision and adds nobody" do
      access_request = request_access

      access_request.decline!(by: lead)

      expect(access_request.reload).to have_attributes(status: "declined", decided_by: lead)
      expect(project.participants.where(member:)).to be_empty
    end
  end

  # added through the participants form or an invitation, the request is answered
  it "is granted when the member joins the project otherwise" do
    access_request = request_access

    create(:participant, project:, member:)

    expect(access_request.reload).to be_granted
  end

  describe "#recipients" do
    let(:manager) { create(:member, :manager, org:) }

    before do
      manager
      create(:member, :owner, org:)
    end

    it "are the project's active leads" do
      lead
      create(:participant, :lead, project:).member.archive!

      expect(request_access.recipients).to contain_exactly(lead)
    end

    it "are the org's active managers and owners when the project has no lead" do
      create(:participant, project:)

      expect(request_access.recipients).to match_array(org.members.where(role: %w[manager owner]))
    end
  end
end
