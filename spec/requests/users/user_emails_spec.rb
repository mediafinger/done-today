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
      patch user_email_path, params: { user: { unconfirmed_email: to, password_challenge: challenge } }
    end

    it "shows the current email" do
      get edit_user_email_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("anna@example.com")
    end

    it "keeps the email until the new one is confirmed and mails both addresses" do
      expect { change_email }
        .to have_enqueued_mail(Users::EmailChangesMailer, :confirm).with(user)
        .and have_enqueued_mail(Users::EmailChangesMailer, :requested).with(user, "anna@example.com", "bell@example.com")

      expect(response).to redirect_to(edit_user_path)
      expect(user.reload).to have_attributes(email: "anna@example.com", unconfirmed_email: "bell@example.com")
    end

    it "shows the pending change" do
      user.update!(unconfirmed_email: "bell@example.com")

      get edit_user_email_path

      expect(response.body).to include("bell@example.com")
    end

    it "cancels a pending change" do
      user.update!(unconfirmed_email: "bell@example.com")

      delete user_email_path

      expect(response).to redirect_to(edit_user_email_path)
      expect(user.reload.unconfirmed_email).to be_nil
    end

    {
      "a missing current password" => { challenge: nil },
      "a wrong current password" => { challenge: "wrong" },
      "the current email" => { to: "anna@example.com" },
      "an email that is already taken" => { to: "taken@example.com" }
    }.each do |refused, attributes|
      it "refuses #{refused} and mails nobody" do
        create(:user, email: "taken@example.com")

        expect { change_email(**attributes) }.not_to have_enqueued_mail

        expect(response).to have_http_status(:unprocessable_content)
        expect(user.reload).to have_attributes(email: "anna@example.com", unconfirmed_email: nil)
      end
    end

    it "names the wrong password" do
      change_email(challenge: "wrong")

      expect(response.body).to include("Current password is invalid")
    end
  end
end
