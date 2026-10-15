require "rails_helper"

RSpec.describe Project do
  describe "slug" do
    let(:org) { create(:org) }

    it "is the parameterized name" do
      expect(create(:project, org:, name: "Website").slug).to eq("website")
    end

    it "lets two orgs each have the same slug" do
      ours = create(:project, org:, name: "Website")
      theirs = create(:project, org: create(:org), name: "Website")

      expect([ ours.slug, theirs.slug ]).to eq(%w[website website])
    end

    it "gets a suffix when the slug is taken within the same org" do
      create(:project, org:, name: "Website")
      other = create(:project, org:, name: "website!")

      expect(other.slug).to match(/\Awebsite-\d+\z/)
    end

    it "is unique per org in the database" do
      create(:project, org:, name: "Website")
      other = create(:project, org:, name: "Shop")

      expect { other.update_column(:slug, "website") }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "is validated per org" do
      create(:project, org:, name: "Website")
      other = create(:project, org:, name: "Shop")
      other.slug = "website"

      expect(other).not_to be_valid
      expect(other.errors[:slug]).to be_present
    end
  end
end
