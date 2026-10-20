require "rails_helper"

RSpec.describe Entries::Create do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }

  before do
    Current.org = org
    Current.user = member.user
  end

  def create_entry(**args)
    described_class.call(project:, member:, date: Date.current, log: "Wrote a spec", **args)
  end

  it "creates the day and the entry, todo by default, with a history by the current user" do
    result = create_entry

    expect(result.saved).to be(true)
    expect(result.entry).to be_persisted
    expect(result.entry).to have_attributes(org:, member:, status: "todo", log: "Wrote a spec")
    expect(result.entry.day).to have_attributes(project:, date: Date.current)
    expect(RecordHistory.where(record_id: result.entry.id)).to contain_exactly(have_attributes(event: "created", user_id: member.user_id, org_id: org.id))
  end

  it "adds to the existing day" do
    day = create(:day, project:)

    expect { create_entry(status: "doing") }.not_to change(Day, :count)
    expect(day.entries.sole.status).to eq("doing")
  end

  it "keeps an invalid entry unsaved, with its errors" do
    result = nil

    expect { result = create_entry(log: "") }.not_to change(Entry, :count)
    expect(result.saved).to be(false)
    expect(result.entry.errors).to include(:log)
  end

  it "creates no day for an invalid entry" do
    expect { create_entry(log: "") }.not_to change(Day, :count)
  end

  context "with a past day" do
    let(:date) { Time.zone.yesterday }

    it "refuses it while locked, without creating the day" do
      result = nil

      expect { result = create_entry(date:) }.not_to change(Day, :count)
      expect(result.saved).to be(false)
      expect(result.entry.errors.details[:base]).to contain_exactly(hash_including(error: :day_locked))
    end

    it "creates the entry once unlocked" do
      expect(create_entry(date:, unlocked: true).saved).to be(true)
    end
  end

  it "rolls the new day back when the history cannot be written" do
    allow(RecordHistoryService).to receive(:call).and_raise(ActiveRecord::StatementInvalid)

    expect { create_entry }.to raise_error(ActiveRecord::StatementInvalid)
    expect([ Entry.count, Day.count ]).to eq([ 0, 0 ])
  end
end
