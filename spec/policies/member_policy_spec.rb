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

    succeed "for a manager" do
      let(:member) { create(:member, :manager, org:) }
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

    context "with a manager" do
      let(:member) { create(:member, :manager, org:) }

      succeed "about a member"

      succeed "about another manager" do
        let(:record) { create(:member, :manager, org:) }
      end

      succeed "about themselves" do
        let(:record) { member }
      end

      # owners are the owners' business
      failed "about an owner" do
        let(:record) { create(:member, :owner, org:) }
      end

      failed "about a deactivated owner" do
        let(:record) { archived_owner }
      end

      # asked with the change applied: giving or taking the owner role is for owners
      failed "about a member to be made owner" do
        let(:record) { colleague.tap { it.role = "owner" } }
      end

      failed "about an owner to be made member" do
        let(:record) { create(:member, :owner, org:).tap { it.role = "member" } }
      end

      succeed "about a member to be made manager" do
        let(:record) { colleague.tap { it.role = "manager" } }
      end
    end

    succeed "for an owner, about a member to be made owner" do
      let(:record) { colleague.tap { it.role = "owner" } }
    end

    succeed "for an owner, about an owner to be made member" do
      let(:record) { create(:member, :owner, org:).tap { it.role = "member" } }
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

  # give or take the owner role, also by invitation
  describe_rule :grant_owner? do
    let(:record) { colleague }

    succeed "for an owner"

    failed "for a manager" do
      let(:member) { create(:member, :manager, org:) }
    end

    failed "for a member" do
      let(:member) { create(:member, org:) }
    end
  end

  # the members of the own org, who lists or changes them is up to index? and manage?
  describe "the default scope" do
    # a guest of the org, and an owner of another org
    let!(:others) { { guest: create(:member, :guest, org:), stranger: create(:member, :owner) } }

    before { colleague }

    def guest = others[:guest]
    def stranger = others[:stranger]

    def visible
      described_class.new(member:).apply_scope(Member.all, type: :active_record_relation)
    end

    it "holds everybody of the own org" do
      expect(visible).to contain_exactly(member, colleague, guest)
    end

    context "with a deactivated member" do
      let(:member) { create(:member, org:).tap(&:archive!) }

      it("shows nobody") { expect(visible).to be_empty }
    end

    context "without a member" do
      let(:member) { nil }

      it("shows nobody") { expect(visible).to be_empty }
    end

    it("never shows another org") { expect(visible).not_to include(stranger) }
  end

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

    context "with a manager" do
      let(:member) { create(:member, :manager, org:) }

      it("offers everybody of the org") { expect(addable).to include(colleague, own_guest, other_guest, member) }
    end

    context "with a project lead" do
      let(:member) { create(:participant, :lead, project: own_guest.projects.sole).member }

      it "offers the internals and the guests of the projects they lead" do
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

  # send, resend and revoke invitations, change roles, deactivate and reactivate
  %i[invite? update? deactivate? reactivate?].each do |rule|
    it { expect(rule).to be_an_alias_of(policy, :manage?) }
  end
end
