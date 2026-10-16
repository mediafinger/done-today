require "rails_helper"

RSpec.describe Day do
  # regression: `has_many :entries, dependent: :destroy` deleted the day's entries with it
  describe "destroying" do
    let(:day) { create(:day) }
    let!(:entry) { create(:entry, day:, member: create(:member, org: day.org)) }

    it "refuses while the day has entries and keeps them" do
      expect { day.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)

      expect(Entry.exists?(entry.id)).to be(true)
    end

    it "is refused by the database too, when callbacks are skipped" do
      expect { described_class.transaction(requires_new: true) { described_class.where(id: day.id).delete_all } }
        .to raise_error(ActiveRecord::InvalidForeignKey)

      expect(Entry.exists?(entry.id)).to be(true)
    end

    it "works for a day without entries" do
      empty = create(:day)

      expect { empty.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
