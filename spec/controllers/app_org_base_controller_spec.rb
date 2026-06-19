require "rails_helper"

RSpec.describe AppOrgBaseController do
  controller(described_class) do
    def index
      render plain: "access granted"
    end
  end

  let(:user) { create(:user) }
  let(:org) { create(:org) }

  describe "GET #index when signed in and is a member of the current organization" do
    let!(:member) { create(:member, org: org, user: user) }
    let!(:user_session) { sign_in(user) }

    before do
      user_session.update!(org: org)
    end

    it "allows access" do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("access granted")
    end
  end

  describe "GET #index when not a member of the current organization" do
    let!(:user_session) { sign_in(user) }

    before do
      user_session.update!(org: nil)
    end

    it "redirects to root path with alert" do
      get :index
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("helpers.controller.unauthorized")
    end
  end
end
