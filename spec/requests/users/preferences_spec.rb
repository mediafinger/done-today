require "rails_helper"

# /preferences duplicated /settings and raised without a selected org.
# Account data lives on /user/edit, org data on /settings.
#
RSpec.describe "GET /preferences" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "is no longer routed to a controller of its own" do
    expect(Rails.application.routes.recognize_path("/preferences"))
      .to include(controller: "application", action: "error_404")
  end

  it "renders the 404 page instead of raising when no org is selected" do
    get "/preferences"

    expect(response).to have_http_status(:not_found)
  end
end
