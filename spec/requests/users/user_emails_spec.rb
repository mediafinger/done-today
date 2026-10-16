require "rails_helper"

RSpec.describe "Users::UserEmails" do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, email: "anna@example.com") }

  describe "without a session" do
    it "redirects GET /user/email/edit to the login" do
      get edit_user_email_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when signed in" do
    before { sign_in(user) }

    def change_email(to: "bell@example.com", challenge: password)
      patch user_email_path, params: { user: { email: to, password_challenge: challenge } }
    end

    it "shows the current email in the form" do
      get edit_user_email_path

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css("input[name='user[email]']")["value"]).to eq("anna@example.com")
    end

    it "changes the email with the current password" do
      change_email

      expect(response).to redirect_to(edit_user_path)
      expect(user.reload.email).to eq("bell@example.com")
    end

    it "refuses a missing current password" do
      change_email(challenge: nil)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Current password is invalid")
      expect(user.reload.email).to eq("anna@example.com")
    end

    it "refuses a wrong current password" do
      change_email(challenge: "wrong")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.email).to eq("anna@example.com")
    end

    it "refuses an email that is already taken" do
      create(:user, email: "taken@example.com")

      change_email(to: "taken@example.com")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.email).to eq("anna@example.com")
    end
  end
end
