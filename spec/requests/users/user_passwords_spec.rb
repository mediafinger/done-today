require "rails_helper"

RSpec.describe "Users::UserPasswords" do
  let(:password) { "correct horse battery staple" }
  let(:new_password) { "a much longer new password" }
  let(:user) { create(:user) }

  describe "without a session" do
    it "redirects GET /user/password/edit to the login" do
      get edit_user_password_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when signed in" do
    before { sign_in(user) }

    def change_password(challenge: password, to: new_password, confirmation: to)
      patch user_password_path,
        params: { user: { password_challenge: challenge, password: to, password_confirmation: confirmation } }
    end

    it "shows the form" do
      get edit_user_password_path

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css("input[name='user[password_challenge]']")).to be_present
    end

    it "changes the password with the current password" do
      change_password

      expect(response).to redirect_to(edit_user_path)
      expect(user.reload.authenticate(new_password)).to be_truthy
    end

    it "refuses a wrong current password" do
      change_password(challenge: "wrong")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "refuses a missing current password" do
      change_password(challenge: nil)

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "refuses a mismatching confirmation" do
      change_password(confirmation: "something else entirely")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "refuses a blank new password instead of silently keeping the old one" do
      change_password(to: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Password can&#39;t be blank")
    end

    it "refuses a too short new password" do
      change_password(to: "short")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "refuses a pwned password in production" do
      allow(AppConf).to receive(:production_env?).and_return(true)
      allow(Pwned::Password).to receive(:new).and_return(instance_double(Pwned::Password, pwned_count: 42))

      change_password

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("might easily be guessed")
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "keeps the current session" do
      change_password
      get edit_user_path

      expect(response).to have_http_status(:ok)
    end

    it "ends every other session of the user" do
      other = user.sessions.create!(user_agent: "other device")
      stranger = create(:user).sessions.create!

      change_password

      expect(Session.exists?(other.id)).to be(false)
      expect(Session.exists?(stranger.id)).to be(true)
      expect(user.sessions.count).to eq(1)
    end

    it "keeps other sessions when the change fails" do
      other = user.sessions.create!(user_agent: "other device")

      change_password(challenge: "wrong")

      expect(Session.exists?(other.id)).to be(true)
    end
  end
end
