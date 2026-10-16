require "rails_helper"

RSpec.describe "Users::Users" do
  let(:user) { create(:user, name: "Anna", email: "anna@example.com") }

  def page = Nokogiri::HTML(response.body)

  describe "without a session" do
    it "redirects GET /user/edit to the login" do
      get edit_user_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when signed in" do
    before { sign_in(user) }

    describe "GET /user/edit" do
      it "shows the name in an editable field and the email" do
        get edit_user_path

        expect(response).to have_http_status(:ok)
        expect(page.at_css("input[name='user[name]']")["value"]).to eq("Anna")
        expect(response.body).to include("anna@example.com")
      end

      it "links to the email, password and sessions pages" do
        get edit_user_path

        [ edit_user_email_path, edit_user_password_path, user_sessions_path ].each do |path|
          expect(page.at_css("main a[href='#{path}']")).to be_present
        end
      end

      it "is linked from the nav" do
        get edit_user_path

        expect(page.at_css("nav a[href='#{edit_user_path}']")).to be_present
      end

      it "works without a selected org" do
        get edit_user_path

        expect(response).to have_http_status(:ok)
      end
    end

    describe "PATCH /user" do
      it "changes the name without the current password" do
        patch user_path, params: { user: { name: "Anna Bell" } }

        expect(response).to redirect_to(edit_user_path)
        expect(user.reload.name).to eq("Anna Bell")
      end

      it "refuses a too short name and keeps the typed value in the form" do
        patch user_path, params: { user: { name: "A" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(page.at_css("input[name='user[name]']")["value"]).to eq("A")
        expect(user.reload.name).to eq("Anna")
      end

      it "ignores attributes outside the form" do
        patch user_path, params: { user: { name: user.name, email: "bell@example.com", admin: true } }

        expect(user.reload.admin).to be(false)
        expect(user.email).to eq("anna@example.com")
      end
    end
  end
end
