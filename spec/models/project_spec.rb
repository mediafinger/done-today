require "rails_helper"

RSpec.describe Project do
  describe "associations" do
    it "has expected associations" do
      org_assoc = described_class.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)

      days_assoc = described_class.reflect_on_association(:days)
      expect(days_assoc.macro).to eq(:has_many)
      expect(days_assoc.options[:dependent]).to eq(:destroy)

      part_assoc = described_class.reflect_on_association(:participants)
      expect(part_assoc.macro).to eq(:has_many)
      expect(part_assoc.options[:inverse_of]).to eq(:project)
      expect(part_assoc.options[:dependent]).to eq(:destroy)

      pi_assoc = described_class.reflect_on_association(:project_integrations)
      expect(pi_assoc.macro).to eq(:has_many)
      expect(pi_assoc.options[:dependent]).to eq(:destroy)

      entries_assoc = described_class.reflect_on_association(:entries)
      expect(entries_assoc.macro).to eq(:has_many)
      expect(entries_assoc.options[:through]).to eq(:days)

      int_assoc = described_class.reflect_on_association(:integrations)
      expect(int_assoc.macro).to eq(:has_many)
      expect(int_assoc.options[:through]).to eq(:project_integrations)

      memb_assoc = described_class.reflect_on_association(:members)
      expect(memb_assoc.macro).to eq(:has_many)
      expect(memb_assoc.options[:through]).to eq(:participants)
    end
  end

  describe "validations" do
    let(:org) { create(:org) }

    it "validates presence of name" do
      project = described_class.new(org: org, name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to be_present
    end

    it "validates uniqueness of name scoped to org_id" do
      create(:project, org: org, name: "Alpha")
      duplicate = build(:project, org: org, name: "Alpha")
      expect(duplicate).not_to be_valid

      other_org = create(:org)
      other_project = build(:project, org: other_org, name: "Alpha")
      expect(other_project).to be_valid
    end
  end

  describe "callbacks" do
    it "sets a slug on creation" do
      project = create(:project, name: "New Feature")
      expect(project.slug).to eq("new-feature")
    end
  end
end
