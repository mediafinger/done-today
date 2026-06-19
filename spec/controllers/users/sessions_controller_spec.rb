require "rails_helper"

RSpec.describe Users::SessionsController do
  let!(:user) { create(:user, password: "password123456", password_confirmation: "password123456") }

  describe "GET #new" do
    it "renders the new template" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "with valid credentials" do
      it "starts a new session and redirects" do
        post :create, params: { email: user.email, password: "password123456" }
        expect(response).to redirect_to(root_url)
        expect(cookies.signed[:session_id]).to be_present
      end
    end

    context "with invalid credentials" do
      it "redirects to login form with alert" do
        post :create, params: { email: user.email, password: "wrong_password" }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:alert]).to eq("Try another email address or password.")
      end
    end
  end

  describe "DELETE #destroy" do
    before do
      sign_in(user)
    end

    it "terminates the session and redirects to new session path" do
      delete :destroy
      expect(response).to redirect_to(new_session_path)
      expect(cookies.signed[:session_id]).to be_nil
    end
  end
end
