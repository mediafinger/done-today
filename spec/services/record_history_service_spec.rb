require "rails_helper"

RSpec.describe RecordHistoryService do
  let(:org) { create(:org) }
  let(:user) { create(:user) }

  describe ".call" do
    it "writes a history record for the given event" do
      entry = create(:entry)

      history = described_class.call(record: entry, event: :created, org:, user:)

      expect(history).to be_persisted
      expect(history.event).to eq("created")
      expect(history.record_type).to eq("Entry")
      expect(history.record_id).to eq(entry.id)
    end

    it "captures the diff of the last save" do
      entry = create(:entry)
      entry.update!(status: "done")

      history = described_class.call(record: entry, event: :updated, org:, user:)

      expect(history.record_changes).to include("status" => %w[doing done])
    end

    it "stores an empty diff for a deletion" do
      history = described_class.call(record: create(:entry), event: :deleted, org:, user:)

      expect(history.record_changes).to eq({})
    end

    it "never writes filtered attributes into the diff" do
      user.update!(password: "another long password")

      history = described_class.call(record: user, event: :updated, org:, user:)

      expect(history.record_changes.keys).not_to include("password", "password_digest")
    end

    it "falls back to Current.org and Current.user" do
      Current.org = org
      Current.user = user

      history = described_class.call(record: create(:entry), event: :created)

      expect(history.org).to eq(org)
      expect(history.user_id).to eq(user.id)
    end

    it "raises a clear error when there is no org in scope" do
      expect { described_class.call(record: create(:entry), event: :created, org: nil, user:) }
        .to raise_error(described_class::MissingContextError, /no org in scope/)
    end

    it "raises a clear error when there is no user in scope" do
      expect { described_class.call(record: create(:entry), event: :created, org:, user: nil) }
        .to raise_error(described_class::MissingContextError, /no user in scope/)
    end
  end
end
