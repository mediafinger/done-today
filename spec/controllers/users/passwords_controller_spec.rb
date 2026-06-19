require "rails_helper"

RSpec.describe Users::PasswordsController, type: :controller do
  let!(:user) { create(:user) }

  describe "GET #new" do
    it "renders the new template" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    it "queues a password reset email if the email matches" do
      expect {
        post :create, params: { email: user.email }
      }.to have_enqueued_mail(PasswordsMailer, :reset)
      expect(response).to redirect_to(new_session_path)
    end

    it "redirects without queueing email if the email does not match" do
      expect {
        post :create, params: { email: "nonexistent@example.com" }
      }.not_to have_enqueued_mail(PasswordsMailer, :reset)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET #edit" do
    context "with invalid token" do
      it "redirects to new password path" do
        get :edit, params: { token: "invalid-token" }
        expect(response).to redirect_to(new_password_path)
        expect(flash[:alert]).to include("invalid or has expired")
      end
    end

    context "with valid token" do
      it "renders the edit template" do
        token = user.generate_token_for(:password_reset)
        get :edit, params: { token: token }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "PATCH #update" do
    let(:token) { user.generate_token_for(:password_reset) }

    context "with matching passwords" do
      it "updates user password and redirects to login" do
        patch :update, params: { token: token, password: "newpassword123", password_confirmation: "newpassword123" }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to eq("Password has been reset.")
        expect(user.reload.authenticate("newpassword123")).to be_truthy
      end
    end

    context "with non-matching passwords" do
      it "redirects to edit page with alert" do
        patch :update, params: { token: token, password: "newpassword123", password_confirmation: "different" }
        expect(response).to redirect_to(edit_password_path(token))
        expect(flash[:alert]).to eq("Passwords did not match.")
      end
    end
  end
end
