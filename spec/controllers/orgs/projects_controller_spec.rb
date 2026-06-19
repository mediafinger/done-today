require "rails_helper"

RSpec.describe Orgs::ProjectsController do
  let(:user) { create(:user) }
  let(:org) { create(:org) }
  let!(:member) { create(:member, org: org, user: user) }
  let!(:project) { create(:project, org: org, name: "Special Task Force") }

  before do
    @user_session = sign_in(user)
    @user_session.update!(org: org)
  end

  describe "GET #show" do
    it "finds the project by slug and renders show" do
      get :show, params: { slug: project.slug }
      expect(response).to have_http_status(:success)
      expect(controller.instance_variable_get(:@project)).to eq(project)
    end
  end

  describe "GET #index" do
    context "with current org" do
      it "returns org projects" do
        get :index
        expect(response).to have_http_status(:success)
        expect(controller.instance_variable_get(:@projects)).to include(project)
      end
    end

    context "without current org" do
      before do
        @user_session.update!(org: nil)
      end

      it "redirects to root path" do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Select an org first")
      end
    end
  end
end
