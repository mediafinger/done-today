require "rails_helper"

RSpec.describe OrgSetup do
  include ActiveSupport::Testing::TimeHelpers

  def setup(**args)
    described_class.call(name: "Acme", owner_email: "olivia@example.com", **args)
  end

  context "with an email that has no account yet" do
    it "creates the org and a pending owner invitation, no account" do
      result = setup(owner_name: "Olivia")

      expect(result.created).to be(true)
      expect(result.member).to be_nil
      expect(result.invitation).to have_attributes(org: result.org, email: "olivia@example.com", role: "owner", name: "Olivia")
      expect(User.exists?(email: "olivia@example.com")).to be(false)
    end

    it "reuses the pending invitation when run again, and keeps its name" do
      first = setup(owner_name: "Olivia")

      second = travel(1.hour) { setup }

      expect(second.created).to be(false)
      expect(second.invitation).to eq(first.invitation)
      expect(second.invitation.reload.name).to eq("Olivia")
      expect(second.invitation.sent_at).to be > first.invitation.sent_at
    end
  end

  context "with an existing account" do
    let!(:user) { create(:user, email: "olivia@example.com") }

    it "makes it the owner of the new org right away" do
      result = setup

      expect(result.invitation).to be_nil
      expect(result.member).to have_attributes(user:, org: result.org, role: "owner")
    end

    it "promotes a member of the existing org" do
      org = create(:org, name: "Acme")
      create(:member, :owner, org:)
      member = create(:member, org:, user:)

      result = setup

      expect(result.created).to be(false)
      expect(result.member).to eq(member)
      expect(member.reload).to be_owner
    end

    it "reactivates an archived member of the existing org as owner" do
      org = create(:org, name: "Acme")
      create(:member, :owner, org:)
      member = create(:member, org:, user:).tap(&:archive!)

      setup

      expect(member.reload).to have_attributes(archived?: false, role: "owner")
    end
  end

  it "creates nothing when the invitation is invalid" do
    expect { setup(owner_email: "no email") }.to raise_error(ActiveRecord::RecordInvalid)

    expect([ Org.count, Invitation.count ]).to eq([ 0, 0 ])
  end
end
