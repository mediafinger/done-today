require "rails_helper"

RSpec.describe Users::DisplayModesController, type: :controller do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    request.env["HTTP_REFERER"] = "http://test.host/current_page"
  end

  describe "POST #dark" do
    it "sets the cookie to dark and redirects" do
      post :dark
      expect(cookies[:display_mode]).to eq("dark")
      expect(response).to redirect_to("http://test.host/current_page")
    end
  end

  describe "POST #light" do
    it "sets the cookie to light and redirects" do
      post :light
      expect(cookies[:display_mode]).to eq("light")
      expect(response).to redirect_to("http://test.host/current_page")
    end
  end

  describe "POST #system" do
    it "deletes the display_mode cookie and redirects" do
      cookies[:display_mode] = "dark"
      post :system
      expect(cookies[:display_mode]).to be_nil
      expect(response).to redirect_to("http://test.host/current_page")
    end
  end
end
