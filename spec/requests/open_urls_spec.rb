require "rails_helper"

# The org | project switcher links to /:org_slug(/:project_slug) directly, old /open URLs are not forwarded.
#
RSpec.describe "GET /open" do
  let(:participant) { create(:participant) }

  before { sign_in(participant.member.user) }

  it "is not found" do
    get "/open/#{participant.org.slug}/#{participant.project.slug}"

    expect(response).to have_http_status(:not_found)
  end
end
