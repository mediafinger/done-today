require "rails_helper"

RSpec.describe Org, type: :model do
  describe "associations" do
    it "has many associations" do
      {
        entries: :destroy,
        days: :destroy,
        integrations: :destroy,
        projects: :destroy,
        record_histories: :destroy
      }.each do |assoc_name, dep|
        assoc = Org.reflect_on_association(assoc_name)
        expect(assoc.macro).to eq(:has_many)
        expect(assoc.options[:dependent]).to eq(dep)
      end

      members_assoc = Org.reflect_on_association(:members)
      expect(members_assoc.macro).to eq(:has_many)
      expect(members_assoc.options[:inverse_of]).to eq(:org)
      expect(members_assoc.options[:dependent]).to eq(:destroy)

      users_assoc = Org.reflect_on_association(:users)
      expect(users_assoc.macro).to eq(:has_many)
      expect(users_assoc.options[:through]).to eq(:members)
    end
  end

  describe "validations" do
    it "validates presence of name" do
      org = Org.new(name: nil)
      expect(org).not_to be_valid
      expect(org.errors[:name]).to be_present
    end

    it "validates uniqueness of name" do
      create(:org, name: "Unique Org")
      duplicate = Org.new(name: "Unique Org")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end
  end

  describe "callbacks" do
    it "sets a slug on creation" do
      org = create(:org, name: "Done Today Solutions")
      expect(org.slug).to eq("done-today-solutions")
    end

    it "resolves slug duplicate conflicts" do
      org1 = create(:org, name: "Same Name")
      org2 = create(:org, name: "Same Name!")
      expect(org2.slug).to start_with("same-name-")
      expect(org2.slug).not_to eq(org1.slug)
    end
  end
end
