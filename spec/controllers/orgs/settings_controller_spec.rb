require "rails_helper"

RSpec.describe Orgs::SettingsController do
  let(:user) { create(:user) }
  let(:org) { create(:org) }
  let!(:member) { create(:member, org: org, user: user) }
  let!(:user_session) { sign_in(user) }

  before do
    routes.draw do
      get "settings" => "orgs/settings#show"
      get "settings/edit" => "orgs/settings#edit"
    end
    user_session.update!(org: org)
    allow(controller).to receive(:default_render)
  end

  after do
    Rails.application.reload_routes!
  end

  describe "GET #show" do
    it "returns success status" do
      get :show
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #edit" do
    it "returns success status" do
      get :edit
      expect(response).to have_http_status(:success)
    end
  end
end
