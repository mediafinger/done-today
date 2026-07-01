require "rails_helper"

RSpec.describe RecordHistory do
  describe "validations" do
    it "validates presence of event" do
      history = build(:record_history, event: nil)
      expect(history).not_to be_valid
      expect(history.errors[:event]).to be_present
    end

    it "validates presence of record_type" do
      history = build(:record_history, record_type: nil)
      expect(history).not_to be_valid
      expect(history.errors[:record_type]).to be_present
    end

    it "validates presence of record_id" do
      history = build(:record_history, record_id: nil)
      expect(history).not_to be_valid
      expect(history.errors[:record_id]).to be_present
    end

    it "validates presence of org_id" do
      history = build(:record_history, org_id: nil)
      expect(history).not_to be_valid
      expect(history.errors[:org_id]).to be_present
    end

    it "validates presence of user_id" do
      history = build(:record_history, user_id: nil)
      expect(history).not_to be_valid
      expect(history.errors[:user_id]).to be_present
    end
  end

  describe "#readonly?" do
    it "returns false for new record" do
      history = build(:record_history)
      expect(history.readonly?).to be false
    end

    it "returns true if created_at is present" do
      history = create(:record_history)
      expect(history.readonly?).to be true
    end
  end

  # BUG #22: Query methods are defined as instance methods instead of class methods
  describe ".get_history_for_org_record (BUG #22)" do
    let(:org) { create(:org) }
    let(:user) { create(:user) }
    let(:entry) { create(:entry, org: org) }
    let!(:history) { create(:record_history, org_id: org.id, record_type: "Entry", record_id: entry.id, user_id: user.id, event: "created") }

    it "returns history for org and record" do
      results = described_class.get_history_for_org_record(org: org, record: entry)
      expect(results).to include(history)
    end
  end

  describe ".get_history_for_org_events (BUG #22)" do
    let(:org) { create(:org) }
    let(:user) { create(:user) }
    let(:entry) { create(:entry, org: org) }
    let!(:history) { create(:record_history, org_id: org.id, record_type: "Entry", record_id: entry.id, user_id: user.id, event: "created") }

    it "returns history for org event and class" do
      results = described_class.get_history_for_org_events(org: org, event: "created", klass: "Entry")
      expect(results).to include(history)
    end
  end

  describe ".get_history_for_user_events (BUG #22)" do
    let(:org) { create(:org) }
    let(:user) { create(:user) }
    let(:entry) { create(:entry, org: org) }
    let!(:history) { create(:record_history, org_id: org.id, record_type: "Entry", record_id: entry.id, user_id: user.id, event: "created") }

    it "returns history for user event and class" do
      results = described_class.get_history_for_user_events(user: user, event: "created", klass: "Entry")
      expect(results).to include(history)
    end
  end
end
