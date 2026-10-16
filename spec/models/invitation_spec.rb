require "rails_helper"

RSpec.describe Invitation do
  include ActiveSupport::Testing::TimeHelpers

  let(:org) { create(:org) }
  let(:invitation) { create(:invitation, org:, email: "ada@example.com") }

  describe "validations" do
    it "stores the email normalized" do
      expect(create(:invitation, email: " Ada@Example.COM ").email).to eq("ada@example.com")
    end

    it "refuses roles that are no org roles" do
      expect(build(:invitation, roles: %w[participant])).not_to be_valid
    end

    it "refuses an email that is already an active member of the org" do
      create(:member, org:, user: create(:user, email: "ada@example.com"))

      invitation = build(:invitation, org:, email: "ada@example.com")

      expect(invitation).not_to be_valid
      expect(invitation.errors.full_messages).to include("ada@example.com is already a member")
    end

    it "accepts the email of a member of another org" do
      create(:member, user: create(:user, email: "ada@example.com"))

      expect(build(:invitation, org:, email: "ada@example.com")).to be_valid
    end

    it "refuses a second pending invitation for the same email and org" do
      invitation

      expect(build(:invitation, org:, email: "ada@example.com")).not_to be_valid
    end

    it "accepts a new invitation once the previous one was accepted" do
      invitation.update!(accepted_at: Time.current)

      expect(build(:invitation, org:, email: "ada@example.com")).to be_valid
    end
  end

  describe "the acceptance token" do
    let(:token) { invitation.generate_token_for(:acceptance) }

    it "finds the invitation" do
      expect(described_class.find_by_token_for(:acceptance, token)).to eq(invitation)
    end

    it "expires after #{described_class::EXPIRES_IN.inspect}" do
      token

      travel(described_class::EXPIRES_IN + 1.second) do
        expect(described_class.find_by_token_for(:acceptance, token)).to be_nil
      end
    end

    it "is used up once the invitation is accepted" do
      token
      invitation.accept!(create(:user, email: "ada@example.com"))

      expect(described_class.find_by_token_for(:acceptance, token)).to be_nil
    end

    it "dies when the invitation is resent" do
      token

      travel(1.minute) { invitation.update!(sent_at: Time.current) }

      expect(described_class.find_by_token_for(:acceptance, token)).to be_nil
      expect(described_class.find_by_token_for(:acceptance, invitation.generate_token_for(:acceptance))).to eq(invitation)
    end

    it "refuses a tampered token" do
      tampered = token.sub(/.\z/) { it == "A" ? "B" : "A" }

      expect(described_class.find_by_token_for(:acceptance, tampered)).to be_nil
    end

    it "refuses another purpose's token" do
      user = create(:user)

      expect(described_class.find_by_token_for(:acceptance, user.generate_token_for(:password_reset))).to be_nil
    end
  end

  describe "#accept!" do
    let(:user) { create(:user, email: "ada@example.com", name: "Ada Lovelace") }

    it "creates the member with the invited roles" do
      invitation.update!(roles: %w[member owner])

      member = invitation.accept!(user)

      expect(member).to have_attributes(org:, user:, roles: %w[member owner], name: "Ada Lovelace")
      expect(invitation.reload).to be_accepted
    end

    it "reactivates an archived member of the same user instead of adding a second one" do
      archived = create(:member, org:, user:, roles: %w[member owner])
      create(:member, :owner, org:)
      archived.archive!

      expect(invitation.accept!(user)).to eq(archived)
      expect(archived.reload).to have_attributes(archived_at: nil, roles: %w[member])
    end

    it "leaves the roles of a member who joined after the invitation was sent" do
      invitation
      member = create(:member, :owner, org:, user:)

      expect(invitation.accept!(user)).to eq(member)
      expect(member.reload.roles).to eq(%w[member owner])
      expect(invitation.reload).to be_accepted
    end

    it "refuses an account with another email" do
      expect { invitation.accept!(create(:user)) }.to raise_error(ArgumentError)
    end

    it "accepts only once" do
      invitation.accept!(user)

      expect { described_class.find(invitation.id).accept!(user) }.to raise_error(described_class::AlreadyAccepted)
    end
  end

  it "is deleted with its org" do
    create(:invitation, org:, invited_by: create(:member, :owner, org:))

    expect { org.destroy! }.to change(described_class, :count).by(-1)
  end
end
