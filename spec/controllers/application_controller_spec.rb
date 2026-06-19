require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe "GET #home" do
    it "renders the home template with success status" do
      get :home
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #error_404" do
    it "renders the error_404 template with not found status" do
      get :error_404, params: { path: "unmatched" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
