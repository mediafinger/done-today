require "rails_helper"

RSpec.describe RecordHistory, type: :model do
  before do
    pending "RecordHistory has column 'changes' causing ActiveRecord::DangerousAttributeError (BUG #22 / Bug #5)"
  end
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
  describe "query methods (BUG #22)", type: :model do
    let(:org) { create(:org) }
    let(:user) { create(:user) }
    let(:entry) { create(:entry, org: org) }
    let!(:history) { create(:record_history, org: org, record_type: "Entry", record_id: entry.id, user_id: user.id, event: "created") }

    describe ".get_history_for_org_record" do
      it "returns history for org and record" do
        pending "Fix bug #22 (defined as instance method instead of class method)"
        results = RecordHistory.get_history_for_org_record(org: org, record: entry)
        expect(results).to include(history)
      end
    end

    describe ".get_history_for_org_events" do
      it "returns history for org event and class" do
        pending "Fix bug #22 (defined as instance method instead of class method)"
        results = RecordHistory.get_history_for_org_events(org: org, event: "created", klass: "Entry")
        expect(results).to include(history)
      end
    end

    describe ".get_history_for_user_events" do
      it "returns history for user event and class" do
        pending "Fix bug #22 (defined as instance method instead of class method)"
        results = RecordHistory.get_history_for_user_events(user: user, event: "created", klass: "Entry")
        expect(results).to include(history)
      end
    end
  end
end
