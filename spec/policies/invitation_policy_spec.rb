require "rails_helper"

RSpec.describe InvitationPolicy do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:record) { create(:invitation, org:) }
  let(:member) { create(:member, :owner, org:) }
  let(:context) { { member: } }

  def project_lead(of: project)
    create(:participant, :lead, project: of).member
  end

  describe_rule :manage? do
    succeed "for an org owner"

    succeed "for an org owner, as owner" do
      let(:record) { create(:invitation, :owner, org:) }
    end

    context "with a manager" do
      let(:member) { create(:member, :manager, org:) }

      succeed "as member"

      succeed "as guest" do
        let(:record) { create(:invitation, :guest, org:, project:) }
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
