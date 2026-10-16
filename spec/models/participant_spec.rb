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

  describe "#role" do
    # the UI gives each participant one role
    it "is the strongest of the roles" do
      expect(described_class.new(roles: %w[observer]).role).to eq("observer")
      expect(described_class.new(roles: %w[observer participant]).role).to eq("participant")
      expect(described_class.new(roles: %w[participant owner]).role).to eq("owner")
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
