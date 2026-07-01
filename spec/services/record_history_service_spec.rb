require "rails_helper"

RSpec.describe RecordHistoryService, type: :service do
  let(:org) { create(:org) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, org: org) }

  describe ".call" do
    it "creates a new RecordHistory with correct attributes" do
      expect {
        described_class.call(
          record: entry,
          org: org,
          user: user,
          event: "updated",
          done_by_admin: true
        )
      }.to change(RecordHistory, :count).by(1)

      history = RecordHistory.last
      expect(history.org_id).to eq(org.id)
      expect(history.user_id).to eq(user.id)
      expect(history.record_type).to eq("Entry")
      expect(history.record_id).to eq(entry.id)
      expect(history.event).to eq("updated")
      expect(history.done_by_admin).to be true
    end
  end
end
