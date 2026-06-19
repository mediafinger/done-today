require "rails_helper"

RSpec.describe Users::PreferencesController do
  let(:user) { create(:user) }
  let!(:user_session) { sign_in(user) }

  before do
    routes.draw do
      get "preferences" => "users/preferences#show"
      get "preferences/edit" => "users/preferences#edit"
    end
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
