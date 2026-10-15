require "rails_helper"

RSpec.describe "Users::Accounts" do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, name: "Anna", email: "anna@example.com") }

  describe "without a session" do
    it "redirects GET /account to the login" do
      get account_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when signed in" do
    before { sign_in(user) }

    describe "GET /account" do
      it "shows the name and email in editable fields" do
        get account_path

        page = Nokogiri::HTML(response.body)
        expect(response).to have_http_status(:ok)
        expect(page.at_css("input[name='user[name]']")["value"]).to eq("Anna")
        expect(page.at_css("input[name='user[email]']")["value"]).to eq("anna@example.com")
      end

      it "is linked from the nav" do
        get account_path

        expect(Nokogiri::HTML(response.body).at_css("nav a[href='#{account_path}']")).to be_present
      end

      it "works without a selected org" do
        get account_path

        expect(response).to have_http_status(:ok)
      end
    end

    describe "PATCH /account" do
      it "changes the name without the current password" do
        patch account_path, params: { user: { name: "Anna Bell", email: user.email } }

        expect(response).to redirect_to(account_path)
        expect(user.reload.name).to eq("Anna Bell")
      end

      it "changes the email with the current password" do
        patch account_path, params: { user: { name: user.name, email: "bell@example.com", password_challenge: password } }

        expect(response).to redirect_to(account_path)
        expect(user.reload.email).to eq("bell@example.com")
      end

      it "refuses an email change without the current password" do
        patch account_path, params: { user: { name: user.name, email: "bell@example.com" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Current password is invalid")
        expect(user.reload.email).to eq("anna@example.com")
      end

      it "refuses an email change with a wrong current password" do
        patch account_path, params: { user: { name: user.name, email: "bell@example.com", password_challenge: "wrong" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(user.reload.email).to eq("anna@example.com")
      end

      it "does not ask for the password when the email only differs in case or whitespace" do
        patch account_path, params: { user: { name: user.name, email: " ANNA@example.com " } }

        expect(response).to redirect_to(account_path)
      end

      it "refuses an email that is already taken" do
        create(:user, email: "taken@example.com")

        patch account_path, params: { user: { name: user.name, email: "taken@example.com", password_challenge: password } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(user.reload.email).to eq("anna@example.com")
      end

      it "refuses a too short name and keeps the typed value in the form" do
        patch account_path, params: { user: { name: "A", email: user.email } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Nokogiri::HTML(response.body).at_css("input[name='user[name]']")["value"]).to eq("A")
        expect(user.reload.name).to eq("Anna")
      end

      it "ignores attributes outside the form" do
        patch account_path, params: { user: { name: user.name, email: user.email, admin: true } }

        expect(user.reload.admin).to be(false)
      end
    end

    describe "PATCH /account/password" do
      let(:new_password) { "a much longer new password" }

      def change_password(challenge: password, to: new_password, confirmation: to)
        patch account_password_path,
          params: { user: { password_challenge: challenge, password: to, password_confirmation: confirmation } }
      end

      it "changes the password with the current password" do
        change_password

        expect(response).to redirect_to(account_path)
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
        get account_path

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
end
