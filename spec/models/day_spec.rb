require "rails_helper"

RSpec.describe Day do
  describe "associations" do
    it "has expected associations" do
      org_assoc = described_class.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)

      proj_assoc = described_class.reflect_on_association(:project)
      expect(proj_assoc.macro).to eq(:belongs_to)
      expect(proj_assoc.options[:inverse_of]).to eq(:days)

      entries_assoc = described_class.reflect_on_association(:entries)
      expect(entries_assoc.macro).to eq(:has_many)
      expect(entries_assoc.options[:inverse_of]).to eq(:day)
      expect(entries_assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "validates presence of date" do
      project = create(:project)
      day = build(:day, project: project, date: nil)
      expect(day).not_to be_valid
      expect(day.errors[:date]).to be_present
    end
  end

  describe "callbacks" do
    it "sets the org from project's org on validation" do
      org = create(:org)
      project = create(:project, org: org)
      day = build(:day, project: project, org: nil)
      day.valid?
      expect(day.org).to eq(org)
    end
  end
end
