require "rails_helper"

# /open/:org(/:project) stored the choice of the org | project switcher in the session.
#   It is kept for bookmarks and forwards to the page, which checks the membership.
#
RSpec.describe "GET /open" do
  let(:participant) { create(:participant) }
  let(:org) { participant.org }
  let(:project) { participant.project }

  before { sign_in(participant.member.user) }

  it "forwards to the org" do
    get "/open/#{org.slug}"

    expect(response).to redirect_to(org_path(org))
  end

  it "forwards to the project" do
    get "/open/#{org.slug}/#{project.slug}"

    expect(response).to redirect_to(project_path(org, project))
  end

  it "escapes what it forwards, so it cannot point to another host" do
    get "/open/%2Fevil"

    expect(response.location).to eq("http://www.example.com/%2Fevil")
  end

  it "is answered by the page: a 404 for an org of someone else" do
    get "/open/#{create(:org).slug}"
    follow_redirect!

    expect(response).to have_http_status(:not_found)
  end
end
