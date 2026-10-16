require "rails_helper"

RSpec.describe InvitationPolicy do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:record) { create(:invitation, org:) }
  let(:member) { create(:member, :owner, org:) }
  let(:context) { { member: } }

  # the org keeps an active owner
  def deactivated_owner
    create(:member, :owner, org:)
    create(:member, :owner, org:).tap(&:archive!)
  end

  # an internal of the org, deactivated
  def deactivated_member(role: "member")
    create(:member, org:, role:).tap(&:archive!)
  end

  # a guest deactivated with their last project
  def former_guest
    create(:member, :guest, org:).tap(&:archive!)
  end

  def project_lead(of: project)
    create(:participant, :lead, project: of).member
  end

  describe_rule :manage? do
    succeed "for an org owner"

    succeed "for an org owner, as owner" do
      let(:record) { create(:invitation, :owner, org:) }
    end

    succeed "for an org owner, to a deactivated owner" do
      let(:record) { create(:invitation, org:, email: deactivated_owner.user.email) }
    end

    context "with a manager" do
      let(:member) { create(:member, :manager, org:) }

      succeed "as member"

      succeed "as guest" do
        let(:record) { create(:invitation, :guest, org:, project:) }
      end

      succeed "as guest, to a deactivated member" do
        let(:record) { create(:invitation, :guest, org:, project:, email: deactivated_member.user.email) }
      end

      # also on the members page, after the project was archived
      succeed "as guest to an archived project" do
        let(:record) { create(:invitation, :guest, org:, project:).tap { project.archive! } }
      end

      failed "as owner" do
        let(:record) { create(:invitation, :owner, org:) }
      end

      # asked with the change assigned
      failed "turning a pending owner invitation into a member one" do
        let(:record) { create(:invitation, :owner, org:).tap { it.role = "member" } }
      end

      failed "making a pending invitation an owner one" do
        let(:record) { create(:invitation, org:).tap { it.role = "owner" } }
      end

      # accepting would reactivate them without the owner role
      failed "to a deactivated owner" do
        let(:record) { create(:invitation, org:, email: deactivated_owner.user.email) }
      end
    end

    context "with a project lead" do
      let(:member) { project_lead }

      succeed "as guest to their project" do
        let(:record) { create(:invitation, :guest, org:, project:) }
      end

      failed "as guest to another project" do
        let(:record) { create(:invitation, :guest, org:, project: create(:project, org:)) }
      end

      failed "as guest to their archived project" do
        let(:record) { create(:invitation, :guest, org:, project:).tap { project.archive! } }
      end

      failed "as member"

      failed "as guest to their project, to a deactivated owner" do
        let(:record) { create(:invitation, :guest, org:, project:, email: deactivated_owner.user.email) }
      end

      # reactivating an internal is up to the org's managers and owners
      failed "as guest to their project, to a deactivated member" do
        let(:record) { create(:invitation, :guest, org:, project:, email: deactivated_member.user.email) }
      end

      failed "as guest to their project, to a deactivated manager" do
        let(:record) { create(:invitation, :guest, org:, project:, email: deactivated_member(role: "manager").user.email) }
      end

      succeed "as guest to their project, to a former guest" do
        let(:record) { create(:invitation, :guest, org:, project:, email: former_guest.user.email) }
      end
    end

    failed "for a member" do
      let(:member) { create(:member, org:) }
    end

    failed "for a guest of the project" do
      let(:record) { create(:invitation, :guest, org:, project:) }
      let(:member) { create(:participant, project:, member: create(:member, :guest, org:)).member }
    end

    failed "for an owner of another org" do
      let(:member) { create(:member, :owner) }
    end

    failed "without a member" do
      let(:member) { nil }
    end
  end

  %i[create? resend? destroy?].each do |rule|
    it { expect(rule).to be_an_alias_of(policy, :manage?) }
  end
end
