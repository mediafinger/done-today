require "rails_helper"

RSpec.describe Entries::Destroy do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:entry) { create(:entry, day: create(:day, project:), member:) }

  before do
    Current.org = org
    Current.user = member.user
  end

  def histories = RecordHistory.where(record_id: entry.id)

  it "deletes the entry, its history keeps the last log" do
    result = described_class.call(entry:)

    expect(result.saved).to be(true)
    expect(Entry.exists?(entry.id)).to be(false)
    expect(histories.sole).to have_attributes(event: "deleted", user_id: member.user_id)
    expect(histories.sole.record_changes["log"]).to eq([ "Wrote some code", nil ])
  end

  it "keeps the day" do
    described_class.call(entry:)

    expect(Day.exists?(entry.day_id)).to be(true)
  end

  context "with an entry of a past day" do
    let(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.yesterday), member:) }

    it "refuses it while locked, and records nothing" do
      result = described_class.call(entry:)

      expect(result.saved).to be(false)
      expect(result.entry.errors.details[:base]).to contain_exactly(hash_including(error: :day_locked))
      expect(Entry.exists?(entry.id)).to be(true)
      expect(histories).to be_empty
    end

    it "deletes it once unlocked" do
      expect(described_class.call(entry:, unlocked: true).saved).to be(true)
    end
  end
end
