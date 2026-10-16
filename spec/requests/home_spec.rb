require "rails_helper"

# Nothing is selected after signing in, so / offers the user's orgs and projects.
#
RSpec.describe "GET /" do
  let(:user) { create(:user) }

  def main_text
    Nokogiri::HTML(response.body).at_css("main").text.squish
  end

  def links
    Nokogiri::HTML(response.body).css("main a").to_h { [ it.text.squish, it["href"] ] }
  end

  it "asks a signed-out visitor to sign in" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "says so when the user belongs to no org" do
    sign_in(user)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(main_text).to include("not a member of any org yet")
  end

  context "with orgs and projects to choose from" do
    let(:org) { create(:org, name: "Acme") }
    let!(:website) { create(:project, org:, name: "Website") }
    let!(:shop) { create(:project, org:, name: "Shop") }
    let!(:beta) { create(:member, user:, org: create(:org, name: "Beta")).org }

    before do
      member = create(:member, org:, user:)
      [ website, shop ].each { create(:participant, member:, project: it) }
      create(:project, org:, name: "Not mine")
      sign_in(user)
    end

    it "links every project the user takes part in, grouped by org" do
      get root_path

      expect(links).to include(
        "Acme" => org_path(org),
        "Shop" => project_path(org, shop),
        "Website" => project_path(org, website),
        "Beta" => org_path(beta)
      )
      expect(links.keys).not_to include("Not mine")
    end

    it "leaves out archived projects" do
      shop.archive!

      get root_path

      expect(links.keys).not_to include("Shop")
    end

    it "leaves out the orgs the user was deactivated in" do
      user.memberships.find_by(org:).archive!

      get root_path

      expect(links.keys).not_to include("Acme")
    end

    it "says so when the user takes part in no project of an org" do
      get root_path

      expect(main_text).to include("not part of any project in Beta yet")
    end
  end

  describe "going straight to today" do
    let(:member) { create(:member, user:) }
    let(:project) { create(:project, org: member.org) }
    let(:today) { edit_day_path(member.org, project, Time.zone.today) }

    it "sends a user with a single project from the sign-in to today" do
      create(:participant, member:, project:)

      sign_in(user)
      follow_redirect!

      expect(response).to redirect_to(today)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "shows an observer today read-only" do
      create(:participant, :observer, member:, project:)
      sign_in(user)

      get root_path
      follow_redirect!

      expect(response.body).not_to include(%(id="new-entry"))
    end

    it "picks the only project of the org opened last" do
      create(:participant, member:, project:)
      other = create(:member, user:)
      create(:participant, member: other, project: create(:project, org: other.org))
      sign_in(user)
      get org_path(member.org)

      get root_path

      expect(response).to redirect_to(today)
    end

    it "stays on the picker when there are several projects to choose from" do
      2.times { create(:participant, member:, project: create(:project, org: member.org)) }
      sign_in(user)

      get root_path

      expect(response).to have_http_status(:ok)
    end

    it "stays on the picker for an org owner who takes part in no project" do
      member.add_role!("owner")
      project
      sign_in(user)

      get root_path

      expect(response).to have_http_status(:ok)
    end
  end
end
