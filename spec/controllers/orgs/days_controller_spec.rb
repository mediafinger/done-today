require "rails_helper"

RSpec.describe Orgs::DaysController do
  let(:user) { create(:user) }
  let(:org) { create(:org) }
  let!(:member) { create(:member, org: org, user: user) }
  let!(:user_session) { sign_in(user) }

  before do
    routes.draw do
      get "days" => "orgs/days#index"
      get "days/:id" => "orgs/days#show"
    end
    user_session.update!(org: org)
    allow(controller).to receive(:default_render)
  end

  after do
    Rails.application.reload_routes!
  end

  describe "GET #index" do
    it "returns success status" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns success status" do
      get :show, params: { id: 1 }
      expect(response).to have_http_status(:success)
    end
  end
end
