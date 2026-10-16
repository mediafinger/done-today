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
      let(:member) { create(:member, org:, role: "owner") }
    end

    # the directory is read-only for them
    succeed "for a member" do
      let(:member) { create(:member, org:) }
    end

    failed "for a guest" do
      let(:member) { create(:member, :guest, org:) }
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
      let(:member) { create(:member, org:, role: "owner") }
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
  it { expect(policy.resolve_rule(:invite?)).to eq(:manage?) }

  # who a project manager may add to a project
  describe "the addable scope" do
    # a guest of the project, and one of another project
    let!(:guests) do
      %i[own other].index_with { create(:participant, project: create(:project, org:), member: create(:member, :guest, org:)).member }
    end

    before { colleague }

    def own_guest = guests[:own]
    def other_guest = guests[:other]

    def addable
      described_class.new(member:).apply_scope(org.members, type: :active_record_relation, name: :addable)
    end

    it "offers an org owner everybody of the org" do
      expect(addable).to include(colleague, own_guest, other_guest, member)
    end

    context "with a project owner" do
      let(:member) { create(:participant, :owner, project: own_guest.projects.sole).member }

      it "offers the internals and the guests of the projects they own" do
        expect(addable).to include(colleague, own_guest)
        expect(addable).not_to include(other_guest)
      end
    end

    context "with a member" do
      let(:member) { create(:member, org:) }

      it("offers no guest") { expect(addable).not_to include(own_guest, other_guest) }
    end

    context "with a guest" do
      let(:member) { own_guest }

      it("offers nobody") { expect(addable).to be_empty }
    end
  end

  %i[update? deactivate? reactivate?].each do |rule|
    it { expect(policy.resolve_rule(rule)).to eq(:manage?) }
  end
end
