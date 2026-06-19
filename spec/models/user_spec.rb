require "rails_helper"

RSpec.describe User do
  describe "associations" do
    it "has many memberships" do
      assoc = described_class.reflect_on_association(:memberships)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:class_name]).to eq("Member")
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many orgs through memberships" do
      assoc = described_class.reflect_on_association(:orgs)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:memberships)
    end

    it "has many sessions" do
      assoc = described_class.reflect_on_association(:sessions)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "normalizations" do
    it "downcases and strips email" do
      user = described_class.new(email: "  Test.Email@Example.Com  ", password: "password123456", name: "Andy")
      user.valid?
      expect(user.email).to eq("test.email@example.com")
    end

    it "strips name" do
      user = described_class.new(email: "test@example.com", password: "password123456", name: "  Andy  ")
      user.valid?
      expect(user.name).to eq("Andy")
    end
  end

  describe "validations" do
    it "validates presence of email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it "validates uniqueness of email" do
      create(:user, email: "duplicate@example.com")
      user2 = build(:user, email: "DUPLICATE@example.com")
      expect(user2).not_to be_valid
      expect(user2.errors[:email]).to be_present
    end

    it "validates presence of name" do
      user = build(:user, name: nil)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it "validates length of name" do
      user = build(:user, name: "ab")
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it "validates email format" do
      user = build(:user, email: "invalid-email")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("invalid-email is not a valid email format")
    end

    it "validates password length on create" do
      user = build(:user, password: "short")
      expect(user).not_to be_valid
    end

    it "allows blank password on update" do
      user = create(:user)
      user.name = "New Name"
      expect(user).to be_valid
    end
  end
end
