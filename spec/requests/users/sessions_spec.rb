require "rails_helper"

RSpec.describe "Users::Sessions" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  def current_session = user.sessions.order(:created_at).last

  describe "GET /account" do
    def page = Nokogiri::HTML(response.body)

    it "lists the user's sessions and marks the current one" do
      user.sessions.create!(user_agent: "Other Browser", ip_address: "10.0.0.7")
      create(:user).sessions.create!(user_agent: "Stranger Browser")

      get account_path

      rows = page.css("#sessions tbody tr").map { it.text.squish }
      expect(rows.size).to eq(2)
      expect(rows).to include(a_string_including("Other Browser", "10.0.0.7"))
      expect(rows).to include(a_string_including("this device"))
      expect(response.body).not_to include("Stranger Browser")
    end

    it "offers to sign out" do
      get account_path

      expect(page.at_css("form[action='#{session_path}'] input[name='_method'][value='delete']")).to be_present
    end

    it "offers to sign out of other sessions only when there are any" do
      get account_path
      expect(page.at_css("form[action='#{account_other_sessions_path}']")).to be_nil

      user.sessions.create!(user_agent: "Other Browser")
      get account_path
      expect(page.at_css("form[action='#{account_other_sessions_path}']")).to be_present
    end
  end

  describe "DELETE /session" do
    it "signs out and deletes the session row" do
      session_id = current_session.id

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(Session.exists?(session_id)).to be(false)
      get account_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "DELETE /account/other_sessions" do
    it "ends every other session of the user and keeps the current one" do
      other = user.sessions.create!(user_agent: "Other Browser")
      stranger = create(:user).sessions.create!

      delete account_other_sessions_path

      expect(response).to redirect_to(account_path)
      expect(flash[:notice]).to eq("Signed out of 1 other session.")
      expect(Session.exists?(other.id)).to be(false)
      expect(Session.exists?(stranger.id)).to be(true)
      get account_path
      expect(response).to have_http_status(:ok)
    end

    it "requires a signed in user" do
      delete session_path
      delete account_other_sessions_path

      expect(response).to redirect_to(new_session_path)
    end
  end
end
