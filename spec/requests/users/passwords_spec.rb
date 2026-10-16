require "rails_helper"

RSpec.describe "Users::Passwords" do
  describe "POST /passwords" do
    it "enqueues the reset mail for a known address" do
      user = create(:user)

      expect { post passwords_path, params: { email: user.email } }
        .to have_enqueued_mail(Users::PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "enqueues nothing for an unknown address" do
      expect { post passwords_path, params: { email: "nobody@example.com" } }
        .not_to have_enqueued_mail

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /passwords/:token/edit" do
    it "shows the form for a valid token" do
      get edit_password_path(create(:user).password_reset_token)

      expect(response).to have_http_status(:ok)
    end

    it "sends an invalid token back to ask for a new link" do
      get edit_password_path("not-a-token")

      expect(response).to redirect_to(new_password_path)
      expect(flash[:alert]).to eq("Password reset link is invalid or has expired.")
    end
  end

  describe "PATCH /passwords/:token" do
    let(:user) { create(:user) }
    let(:token) { user.password_reset_token }

    def reset(password, confirmation = password)
      patch password_path(token), params: { password:, password_confirmation: confirmation }
    end

    it "sets the new password, the old one stops working" do
      reset("a brand new password")

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate("a brand new password")).to eq(user)
      expect(user.authenticate("correct horse battery staple")).to be(false)
    end

    it "uses the link up: it does not work a second time" do
      reset("a brand new password")

      get edit_password_path(token)

      expect(response).to redirect_to(new_password_path)
    end

    it "keeps the password when the confirmation differs" do
      reset("a brand new password", "another new password")

      expect(response).to redirect_to(edit_password_path(token))
      expect(user.reload.authenticate("correct horse battery staple")).to eq(user)
    end

    it "keeps the password when the new one is too short" do
      reset("too short")

      expect(user.reload.authenticate("correct horse battery staple")).to eq(user)
    end
  end
end
