require "rails_helper"

# Opening an org or a project remembers it on the user, so / on any device, in any
#   later session, picks up where they left off.
#
RSpec.describe "Remembering the last org and project" do
  let(:org) { create(:org) }
  let(:member) { create(:member, org:) }
  let(:user) { member.user }
  let(:project) { create(:project, org:) }
  let(:today) { Time.zone.today }

  # two orgs and two projects, so nothing is unambiguous enough to be auto-selected
  before do
    create(:participant, member:, project:)
    create(:participant, member:, project: create(:project, org:))
    create(:member, user:)
    sign_in(user)
  end

  def sign_in_again
    delete session_path
    sign_in(user)
  end

  it "sends / to today in the project opened last, also in a new session" do
    get project_path(org, project)
    sign_in_again

    get root_path

    expect(response).to redirect_to(edit_day_path(org, project, today))
  end

  it "remembers a project when one of its pages is opened" do
    get day_path(org, project, today)

    expect(user.reload).to have_attributes(last_org: org, last_project: project)
  end

  it "keeps the project when only its org is opened again" do
    get project_path(org, project)
    get org_path(org)

    expect(user.reload.last_project).to eq(project)
  end

  it "offers the picker after an org without a project was opened" do
    get project_path(org, project)
    get org_path(user.orgs.where.not(id: org.id).first)

    get root_path

    expect(response).to have_http_status(:ok)
  end

  it "offers the picker once the user no longer takes part in the project" do
    get project_path(org, project)
    member.participations.find_by(project:).destroy!

    get root_path

    expect(response).to have_http_status(:ok)
  end

  it "offers the picker to a user who never opened anything" do
    get root_path

    expect(response).to have_http_status(:ok)
  end
end
