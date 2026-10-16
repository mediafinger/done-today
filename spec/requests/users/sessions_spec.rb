require "rails_helper"

RSpec.describe "Users::Sessions" do
  let!(:user) { create(:user, email: "ada@example.com") }

  describe "GET /session/new" do
    it "shows the form to a visitor" do
      get new_session_path

      expect(response).to have_http_status(:ok)
    end

    it "sends a signed-in user to /" do
      sign_in(user)

      get new_session_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    it "signs in with email and password, and records where from" do
      post session_path, params: { email: "ada@example.com", password: "correct horse battery staple" },
        headers: { "HTTP_USER_AGENT" => "Specs" }

      expect(response).to redirect_to(root_url)
      expect(user.sessions.sole).to have_attributes(user_agent: "Specs", ip_address: "127.0.0.1")
      expect(cookies[:session_id]).to be_present
    end

    it "finds the account regardless of the email's case and spaces" do
      post session_path, params: { email: " ADA@example.com ", password: "correct horse battery staple" }

      expect(user.sessions.count).to eq(1)
    end

    it "refuses a wrong password without telling which part was wrong" do
      post session_path, params: { email: user.email, password: "wrong horse battery staple" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
      expect(user.sessions).to be_empty
    end

    it "returns to the page that asked for the sign-in" do
      get settings_path

      sign_in(user)

      expect(response).to redirect_to(settings_url)
    end

    it "is rate limited" do
      allow(Users::SessionsController.cache_store).to receive(:increment).and_return(11)

      sign_in(user)

      expect(response).to redirect_to(new_session_url)
      expect(flash[:alert]).to eq("Try again later.")
      expect(user.sessions).to be_empty
    end
  end

  describe "DELETE /session" do
    it "ends this session only, the browser has to sign in again" do
      other = user.sessions.create!
      sign_in(user)

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(user.sessions.reload).to contain_exactly(other)

      get settings_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
