require "rails_helper"

RSpec.describe Orgs::MembersController do
  let(:user) { create(:user) }
  let(:org) { create(:org) }
  let!(:member) { create(:member, org: org, user: user) }
  let!(:user_session) { sign_in(user) }

  before do
    routes.draw do
      get "index" => "orgs/members#index"
      post "create" => "orgs/members#create"
      delete "destroy" => "orgs/members#destroy"
      patch "update" => "orgs/members#update"
    end
    user_session.update!(org: org)
    allow(controller).to receive(:default_render)
  end

  after do
    Rails.application.reload_routes!
  end

  describe "GET #index" do
    it "renders the index with success status" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    it "returns success status" do
      post :create, params: { member: { org_id: org.id, user_id: user.id } }
      expect(response).to have_http_status(:success)
    end
  end

  describe "DELETE #destroy" do
    it "returns success status" do
      delete :destroy, params: { id: member.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH #update with valid roles" do
    it "updates the member roles in the database" do
      pending "Fix Bug #19 (member.save is not called in update action) and params.expect bug"
      patch :update, params: {
        member: { member_id: member.id, roles: ["owner"] }
      }
      expect(member.reload.roles).to eq(["owner"])
    end

    it "mutates roles in memory but does not persist them due to Bug #19" do
      pending "Fix parameter parsing bug: params.expect(:member) fails when member is a hash"
      patch :update, params: {
        member: { member_id: member.id, roles: ["owner"] }
      }
      expect(member.reload.roles).not_to eq(["owner"])
    end
  end

  describe "PATCH #update with invalid roles" do
    it "assigns error message and does not change roles" do
      pending "Fix parameter parsing bug: params.expect(:member) fails when member is a hash"
      patch :update, params: {
        member: { member_id: member.id, roles: ["invalid_role"] }
      }
      expect(controller.instance_variable_get(:@error_message)).to include("invalid_roles")
      expect(member.reload.roles).not_to include("invalid_role")
    end
  end
end
