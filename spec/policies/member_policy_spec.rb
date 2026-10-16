require "rails_helper"

RSpec.describe MemberPolicy do
  let(:org) { create(:org) }
  let(:colleague) { create(:member, org:) }
  let(:member) { create(:member, :owner, org:) }
  let(:context) { { member: } }

  # the org keeps an owner while another one is archived
  def archived_owner
    create(:member, :owner, org:)
    create(:member, :owner, org:).tap(&:archive!)
  end

  describe_rule :index? do
    let(:record) { Member }

    succeed "for an owner"

    succeed "for a member with only the owner role" do
      let(:member) { create(:member, org:, roles: %w[owner]) }
    end

    failed "for a member" do
      let(:member) { create(:member, org:) }
    end

    failed "for an archived owner" do
      let(:member) { archived_owner }
    end

    failed "without a member" do
      let(:member) { nil }
    end
  end

  describe_rule :manage? do
    let(:record) { colleague }

    succeed "for an owner"

    succeed "for a member with only the owner role" do
      let(:member) { create(:member, org:, roles: %w[owner]) }
    end

    succeed "for an owner, about themselves" do
      let(:record) { member }
    end

    succeed "for an owner, about a deactivated member, to reactivate them" do
      let(:record) { colleague.tap(&:archive!) }
    end

    failed "for a member" do
      let(:member) { create(:member, org:) }
    end

    failed "for an owner of another org" do
      let(:member) { create(:member, :owner) }
    end

    failed "for an archived owner" do
      let(:member) { archived_owner }
    end

    failed "without a member" do
      let(:member) { nil }
    end
  end

  # send, resend and revoke invitations
  it { expect(policy.resolve_rule(:invite?)).to eq(:index?) }

  %i[update? deactivate? reactivate?].each do |rule|
    it { expect(policy.resolve_rule(rule)).to eq(:manage?) }
  end
end
