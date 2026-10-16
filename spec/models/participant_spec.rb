require "rails_helper"

RSpec.describe Participant do
  let(:project) { create(:project) }

  it "takes part in a project only once" do
    participant = create(:participant, project:)

    duplicate = described_class.new(project:, member: participant.member)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:member]).to be_present
  end

  it "has to be a member of the project's org" do
    stranger = described_class.new(project:, member: create(:member))

    expect(stranger).not_to be_valid
    expect(stranger.errors[:member]).to be_present
  end

  describe "guests" do
    let(:guest) { create(:participant, project:, member: create(:member, :guest, org: project.org)).member }

    it "refuses a guest as project lead" do
      participant = guest.participations.sole

      expect(participant.update(roles: %w[lead])).to be(false)
      expect(participant.errors[:roles]).to include("lead is not a project role for guests")
    end

    it "deactivates a guest whose last participation is removed" do
      guest.participations.sole.destroy!

      expect(guest.reload).to be_archived
    end

    it "keeps a guest with another participation active" do
      create(:participant, member: guest, project: create(:project, org: project.org))

      guest.participations.find_by!(project:).destroy!

      expect(guest.reload).not_to be_archived
    end

    it "leaves members without a project active" do
      member = create(:participant, project:).member

      member.participations.sole.destroy!

      expect(member.reload).not_to be_archived
    end
  end

  describe "#role" do
    # the UI gives each participant one role
    it "is the strongest of the roles" do
      expect(described_class.new(roles: %w[observer]).role).to eq("observer")
      expect(described_class.new(roles: %w[observer participant]).role).to eq("participant")
      expect(described_class.new(roles: %w[participant lead]).role).to eq("lead")
    end
  end

  # removing someone from a project takes their access, not their history
  it "keeps the member's entries when destroyed" do
    participant = create(:participant, project:)
    entry = create(:entry, day: create(:day, project:), member: participant.member)

    participant.destroy!

    expect(Entry.exists?(entry.id)).to be(true)
    expect(project.entries).to include(entry)
  end
end
