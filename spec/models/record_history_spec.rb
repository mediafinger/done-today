require "rails_helper"

RSpec.describe RecordHistory do
  describe "the record_changes column" do
    it "persists and reads back the diff" do
      history = create(:record_history, record_changes: { "status" => %w[todo done] })

      expect(history.reload.record_changes).to eq("status" => %w[todo done])
    end

    it "accepts an empty diff" do
      expect(build(:record_history, record_changes: {})).to be_valid
    end

    it "does not shadow ActiveModel::Dirty's #changes" do
      expect(described_class.column_names).to include("record_changes")
      expect(described_class.new.changes).to be_a(Hash)
    end
  end

  describe "readonly" do
    it "refuses updates once persisted" do
      history = create(:record_history)

      expect { history.update!(event: "updated") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe "scopes" do
    it "finds the history of one record" do
      entry = create(:entry)
      org = entry.org
      wanted = create(:record_history, org:, record_type: "Entry", record_id: entry.id)
      create(:record_history, org:, record_type: "Entry", record_id: SecureRandom.uuid)

      expect(described_class.for_org_record(org:, record: entry)).to contain_exactly(wanted)
    end

    it "finds the org's events of one type" do
      org = create(:org)
      wanted = create(:record_history, org:, event: "deleted", record_type: "Entry")
      create(:record_history, org:, event: "created", record_type: "Entry")

      expect(described_class.for_org_events(org:, event: "deleted", klass: Entry)).to contain_exactly(wanted)
    end

    it "finds one user's events of one type" do
      user = create(:user)
      wanted = create(:record_history, event: "created", record_type: "Entry", user_id: user.id)
      create(:record_history, event: "created", record_type: "Entry")

      expect(described_class.for_user_events(user:, event: "created", klass: Entry)).to contain_exactly(wanted)
    end
  end
end
