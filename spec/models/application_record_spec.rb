require "rails_helper"

RSpec.describe ApplicationRecord do
  before do
    Current.org = org
    Current.user = create(:user)
  end

  let(:org) { create(:org) }
  let(:day) { create(:day, project: create(:project, org:)) }

  describe "#create_with_history" do
    it "saves the record and logs a :created event" do
      entry = Entry.new(day:, member: create(:member, org:), log: "Wrote some code")

      expect { entry.create_with_history }.to change(RecordHistory, :count).by(1)
      expect(entry).to be_persisted
      expect(RecordHistory.last.event).to eq("created")
    end

    it "logs nothing when the record is invalid" do
      entry = Entry.new(day:, member: create(:member, org:), log: "")

      expect { entry.create_with_history }.not_to change(RecordHistory, :count)
    end
  end

  describe "#update_with_history" do
    it "logs an :updated event with the diff" do
      entry = create(:entry, day:, member: create(:member, org:))
      entry.status = "done"

      expect { entry.update_with_history }.to change(RecordHistory, :count).by(1)
      expect(RecordHistory.last.record_changes).to include("status")
    end

    it "logs nothing when nothing changed" do
      entry = create(:entry, day:, member: create(:member, org:))

      expect { entry.update_with_history }.not_to change(RecordHistory, :count)
      expect(entry.update_with_history).to be(true)
    end

    it "rolls the save back when the history cannot be written" do
      entry = create(:entry, day:, member: create(:member, org:))
      entry.status = "done"
      allow(RecordHistoryService).to receive(:call).and_raise(ActiveRecord::StatementInvalid)

      expect { entry.update_with_history }.to raise_error(ActiveRecord::StatementInvalid)
      expect(entry.reload.status).to eq("doing")
    end
  end

  describe "#destroy_with_history" do
    it "logs a :deleted event and removes the record" do
      entry = create(:entry, day:, member: create(:member, org:))

      expect { entry.destroy_with_history }.to change(Entry, :count).by(-1)
      expect(RecordHistory.last.event).to eq("deleted")
    end
  end
end
