require "rails_helper"

RSpec.describe LandingService do
  let(:org) { create(:org) }
  let(:member) { create(:member, org:) }
  let(:user) { member.user }
  let(:project) { create(:project, org:) }

  before { create(:participant, member:, project:) }

  def landing
    described_class.call(user: user.reload)
  end

  context "with several orgs and projects" do
    before do
      create(:participant, member:, project: create(:project, org:))
      create(:member, user:)
    end

    it "is empty when nothing was remembered" do
      expect(landing).to have_attributes(org: nil, project: nil)
    end

    it "returns the only project of the remembered org" do
      other_org = create(:member, user:).org
      only_project = create(:project, org: other_org)
      create(:participant, member: user.memberships.find_by(org: other_org), project: only_project)
      user.remember_last_visit!(org: other_org)

      expect(landing).to have_attributes(org: other_org, project: only_project)
    end
  end

  it "returns the only org and project when nothing was remembered" do
    expect(landing).to have_attributes(org:, project:)
  end

  it "skips archived projects when looking for the only one" do
    create(:participant, member:, project: create(:project, org:, archived_at: 1.day.ago))

    expect(landing).to have_attributes(org:, project:)
  end

  it "does not pick a project for an org owner who takes part in none" do
    owner = create(:member, :owner, org: create(:org))
    create(:project, org: owner.org)

    expect(described_class.call(user: owner.user)).to have_attributes(org: owner.org, project: nil)
  end

  it "returns the remembered org and project" do
    user.remember_last_visit!(org:, project:)

    expect(landing).to have_attributes(org:, project:)
  end

  it "keeps the org but drops a project the user may no longer read" do
    user.remember_last_visit!(org:, project:)
    member.participations.destroy_all

    expect(landing).to have_attributes(org:, project: nil)
  end

  it "drops an archived project" do
    user.remember_last_visit!(org:, project:)
    project.archive!

    expect(landing).to have_attributes(org:, project: nil)
  end

  it "lands org owners in a project they read without taking part in it" do
    owned = create(:project, org:)
    member.add_role!("owner")
    user.remember_last_visit!(org:, project: owned)

    expect(landing).to have_attributes(org:, project: owned)
  end

  it "returns nothing once the user was deactivated in the org" do
    user.remember_last_visit!(org:, project:)
    member.archive!

    expect(landing).to have_attributes(org: nil, project: nil)
  end

  it "ignores a remembered project of another org" do
    create(:participant, member:, project: create(:project, org:))
    user.update_columns(last_org_id: org.id, last_project_id: create(:project).id) # rubocop:disable Rails/SkipsModelValidations

    expect(landing).to have_attributes(org:, project: nil)
  end
end
