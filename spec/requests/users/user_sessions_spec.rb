require "rails_helper"

RSpec.describe "Users::UserSessions" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  def current_session = user.sessions.order(:created_at).last
  def page = Nokogiri::HTML(response.body)

  describe "GET /user/sessions" do
    it "lists the user's sessions and marks the current one" do
      user.sessions.create!(user_agent: "Other Browser", ip_address: "10.0.0.7")
      create(:user).sessions.create!(user_agent: "Stranger Browser")

      get user_sessions_path

      rows = page.css("#sessions tbody tr").map { it.text.squish }
      expect(rows.size).to eq(2)
      expect(rows).to include(a_string_including("Other Browser", "10.0.0.7"))
      expect(rows).to include(a_string_including("this device"))
      expect(response.body).not_to include("Stranger Browser")
    end

    it "offers to sign out of each session" do
      other = user.sessions.create!(user_agent: "Other Browser")

      get user_sessions_path

      [ current_session, other ].each do |device_session|
        expect(page.at_css("form[action='#{user_session_path(device_session)}'] input[name='_method'][value='delete']")).to be_present
      end
    end

    it "offers to sign out of other sessions only when there are any" do
      get user_sessions_path
      expect(page.at_css("form[action='#{destroy_others_user_sessions_path}']")).to be_nil

      user.sessions.create!(user_agent: "Other Browser")
      get user_sessions_path
      expect(page.at_css("form[action='#{destroy_others_user_sessions_path}']")).to be_present
    end
  end

  describe "DELETE /user/sessions/:id" do
    it "signs out another session and keeps the current one" do
      other = user.sessions.create!(user_agent: "Other Browser")

      delete user_session_path(other)

      expect(response).to redirect_to(user_sessions_path)
      expect(Session.exists?(other.id)).to be(false)
      get user_sessions_path
      expect(response).to have_http_status(:ok)
    end

    it "signs out when it is the current session" do
      session_id = current_session.id

      delete user_session_path(session_id)

      expect(response).to redirect_to(new_session_path)
      expect(Session.exists?(session_id)).to be(false)
      get edit_user_path
      expect(response).to redirect_to(new_session_path)
    end

    it "does not touch sessions of other users" do
      stranger = create(:user).sessions.create!

      delete user_session_path(stranger)

      expect(response).to have_http_status(:not_found)
      expect(Session.exists?(stranger.id)).to be(true)
    end
  end

  describe "DELETE /user/sessions/destroy_others" do
    it "ends every other session of the user and keeps the current one" do
      other = user.sessions.create!(user_agent: "Other Browser")
      stranger = create(:user).sessions.create!

      delete destroy_others_user_sessions_path

      expect(response).to redirect_to(user_sessions_path)
      expect(flash[:notice]).to eq("Signed out of 1 other session.")
      expect(Session.exists?(other.id)).to be(false)
      expect(Session.exists?(stranger.id)).to be(true)
      get user_sessions_path
      expect(response).to have_http_status(:ok)
    end

    it "requires a signed in user" do
      delete session_path
      delete destroy_others_user_sessions_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "DELETE /session" do
    it "signs out and deletes the session row" do
      session_id = current_session.id

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(Session.exists?(session_id)).to be(false)
    end
  end
end
