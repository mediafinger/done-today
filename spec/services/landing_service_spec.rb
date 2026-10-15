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

  it "is empty when nothing was remembered" do
    expect(landing).to have_attributes(org: nil, project: nil)
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
    user.update_columns(last_org_id: org.id, last_project_id: create(:project).id) # rubocop:disable Rails/SkipsModelValidations

    expect(landing).to have_attributes(org:, project: nil)
  end
end
