require "rails_helper"

# After signing in, the new Session row carries no org and no project until the
# user opens one via /open/:slug_org. Every page that queries through
# `current_org` / `current_project` used to raise NoMethodError on nil in that
# window -- which is exactly the state a user lands in right after logging in.
#
RSpec.describe "Pages reached before an org is selected" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /entries" do
    it "redirects instead of raising when no org is selected" do
      get entries_path

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it "redirects for every mode and grouping" do
      [ { mode: "read" }, { mode: "edit" }, { date: "2026-03-01" }, { member_id: SecureRandom.uuid } ].each do |params|
        get entries_path(params)

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "POST /entries" do
    it "redirects instead of raising" do
      post entries_path, params: { entry: { date: "2026-03-01", log: "Wrote a spec" } }

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /projects/:slug" do
    it "redirects instead of raising" do
      get project_path("anything")

      expect(response).to have_http_status(:redirect)
    end
  end

  context "when an org is selected but no project is" do
    let(:member) { create(:member, user:) }

    before do
      get open_path(member.org.slug)
    end

    it "sends the user to pick a project rather than raising" do
      get entries_path

      expect(response).to redirect_to(projects_path)
    end
  end
end
