require "rails_helper"

RSpec.describe "Users::DisplayModes" do
  let(:user) { create(:user) }

  def page = Nokogiri::HTML(response.body)

  describe "without a session" do
    it "redirects PATCH /user/display_mode to the login" do
      patch user_display_mode_path, params: { user: { display_mode: "dark" } }

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when signed in" do
    before { sign_in(user) }

    describe "PATCH /user/display_mode" do
      it "stores the display mode on the user" do
        patch user_display_mode_path, params: { user: { display_mode: "dark" } }

        expect(user.reload.display_mode).to eq("dark")
      end

      # regression: `redirect_to request.referrer` raised on a nil referrer
      it "redirects to the account page when the request has no referrer" do
        patch user_display_mode_path, params: { user: { display_mode: "dark" } }

        expect(response).to redirect_to(edit_user_path)
      end

      it "redirects back to the referrer" do
        patch user_display_mode_path, params: { user: { display_mode: "light" } },
          headers: { "HTTP_REFERER" => "http://www.example.com/settings" }

        expect(response).to redirect_to("http://www.example.com/settings")
      end

      it "does not follow a referrer from another host" do
        patch user_display_mode_path, params: { user: { display_mode: "light" } },
          headers: { "HTTP_REFERER" => "https://evil.example.org/" }

        expect(response).to redirect_to(edit_user_path)
      end

      it "refuses an unknown display mode" do
        user.update!(display_mode: "dark")

        patch user_display_mode_path, params: { user: { display_mode: "sepia" } }

        expect(response).to redirect_to(edit_user_path)
        expect(flash[:alert]).to be_present
        expect(user.reload.display_mode).to eq("dark")
      end
    end

    describe "the layout" do
      it "sets data-theme on <html> for dark and light" do
        %w[dark light].each do |mode|
          user.update!(display_mode: mode)

          get edit_user_path

          expect(page.at_css("html")["data-theme"]).to eq(mode)
        end
      end

      it "leaves data-theme off for system, so the OS preference applies" do
        get edit_user_path

        expect(page.at_css("html")["data-theme"]).to be_nil
      end
    end

    describe "GET /user/edit" do
      it "offers the three display modes with the current one checked" do
        user.update!(display_mode: "light")

        get edit_user_path

        form = page.at_css("form[action='#{user_display_mode_path}']")
        expect(form.css("input[type=radio][name='user[display_mode]']").map { it["value"] }).to eq(%w[system light dark])
        expect(form.at_css("input[type=radio][checked]")["value"]).to eq("light")
      end
    end

    describe "GET /settings" do
      it "no longer carries the display mode buttons" do
        get settings_path

        expect(response).to have_http_status(:ok)
        expect(page.at_css("input[name='user[display_mode]']")).to be_nil
        expect(response.body).not_to include("dark_mode")
      end
    end
  end
end
