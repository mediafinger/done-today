require "rails_helper"

RSpec.describe Entries::Update do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:entry) { create(:entry, day: create(:day, project:), member:) }

  before do
    Current.org = org
    Current.user = member.user
  end

  def histories = RecordHistory.where(record_id: entry.id)

  it "changes the given attributes only, with a history by the current user" do
    result = described_class.call(entry:, attributes: { status: "done" })

    expect(result.saved).to be(true)
    expect(entry.reload).to have_attributes(status: "done", log: "Wrote some code")
    expect(histories).to contain_exactly(have_attributes(event: "updated", user_id: member.user_id))
  end

  it "takes a blank log to the validations instead of dropping it" do
    result = described_class.call(entry:, attributes: { "log" => "" })

    expect(result.saved).to be(false)
    expect(result.entry.errors).to include(:log)
    expect(entry.reload.log).to eq("Wrote some code")
  end

  it "ignores attributes other than log and status" do
    other_day = create(:day, project:, date: Date.tomorrow)

    described_class.call(entry:, attributes: { log: "Moved?", day_id: other_day.id })

    expect(entry.reload).to have_attributes(log: "Moved?", day_id: entry.day_id)
  end

  context "with an entry of a past day" do
    let(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.yesterday), member:) }

    it "refuses it while locked, and records nothing" do
      result = described_class.call(entry:, attributes: { log: "Changed in passing" })

      expect(result.saved).to be(false)
      expect(result.entry.errors.details[:base]).to contain_exactly(hash_including(error: :day_locked))
      expect(entry.reload.log).to eq("Wrote some code")
      expect(histories).to be_empty
    end

    it "updates it once unlocked" do
      expect(described_class.call(entry:, attributes: { log: "Fixed it after all" }, unlocked: true).saved).to be(true)
    end
  end
end
