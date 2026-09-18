require "rails_helper"

RSpec.describe Entry do
  describe "factory" do
    it "creates a persisted entry wired to an org, day and member" do
      entry = create(:entry)

      expect(entry).to be_persisted
      expect(entry.org).to eq(entry.day.org)
      expect(entry.project).to eq(entry.day.project)
    end
  end

  describe "#set_org" do
    it "copies the org from the day when none is given" do
      day = create(:day)

      expect(build(:entry, day:, org: nil).tap(&:validate).org).to eq(day.org)
    end
  end

  describe "status predicates" do
    it "reports the matching status and only that one" do
      expect(build(:entry, :todo)).to be_todo
      expect(build(:entry, :done)).to be_done
      expect(build(:entry, :todo)).not_to be_done
    end
  end
end
