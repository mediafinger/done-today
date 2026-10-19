require "rails_helper"

RSpec.describe OrgPolicy do
  let(:org) { create(:org) }
  let(:record) { org }
  let(:member) { create(:member, :owner, org:) }
  let(:context) { { member: } }

  describe_rule :read_tag_times_report? do
    succeed "for an owner"

    succeed "for a manager" do
      let(:member) { create(:member, :manager, org:) }
    end

    failed "for a member" do
      let(:member) { create(:member, org:) }
    end

    failed "for a guest" do
      let(:member) { create(:member, :guest, org:) }
    end

    failed "for a member leading a project" do
      let(:member) { create(:participant, :lead, project: create(:project, org:), member: create(:member, org:)).member }
    end

    failed "for an archived owner" do
      let(:member) do
        create(:member, :owner, org:)
        create(:member, :owner, org:).tap(&:archive!)
      end
    end

    failed "for the owner of another org" do
      let(:record) { create(:org) }
    end

    failed "without a member" do
      let(:member) { nil }
    end
  end
end
