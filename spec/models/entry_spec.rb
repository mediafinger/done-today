require "rails_helper"

RSpec.describe Entry, type: :model do
  describe "associations" do
    it "has expected associations" do
      day_assoc = Entry.reflect_on_association(:day)
      expect(day_assoc.macro).to eq(:belongs_to)

      org_assoc = Entry.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)

      member_assoc = Entry.reflect_on_association(:member)
      expect(member_assoc.macro).to eq(:belongs_to)

      proj_assoc = Entry.reflect_on_association(:project)
      expect(proj_assoc.macro).to eq(:has_one)
      expect(proj_assoc.options[:through]).to eq(:day)
    end
  end

  describe "validations" do
    it "validates presence of log" do
      entry = build(:entry, log: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:log]).to be_present
    end

    it "validates presence of status" do
      entry = build(:entry, status: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:status]).to be_present
    end

    it "validates inclusion of status in states" do
      entry = build(:entry, status: "invalid")
      expect(entry).not_to be_valid
      expect(entry.errors[:status]).to be_present
    end
  end

  describe "callbacks" do
    it "sets the org from day's org on validation" do
      org = create(:org)
      day = create(:day, org: org)
      entry = build(:entry, day: day, org: nil)
      entry.valid?
      expect(entry.org).to eq(org)
    end
  end

  describe "predicates" do
    it "checks status helpers" do
      expect(build(:entry, status: "todo")).to be_todo
      expect(build(:entry, status: "doing")).to be_doing
      expect(build(:entry, status: "done")).to be_done
    end
  end

  describe "time-based helpers" do
    let(:org) { create(:org) }
    let(:day_today) { create(:day, org: org, date: Date.current) }
    let(:day_tomorrow) { create(:day, org: org, date: Date.tomorrow) }
    let(:day_yesterday) { create(:day, org: org, date: Date.yesterday) }

    it "identifies if today?" do
      expect(build(:entry, day: day_today)).to be_today
      expect(build(:entry, day: day_tomorrow)).not_to be_today
    end

    it "identifies if future?" do
      expect(build(:entry, day: day_tomorrow)).to be_future
      expect(build(:entry, day: day_today)).not_to be_future
    end

    it "identifies if past?" do
      expect(build(:entry, day: day_yesterday)).to be_past
      expect(build(:entry, day: day_today)).not_to be_past
    end
  end
end
