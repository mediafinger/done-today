require "rails_helper"

RSpec.describe "Users::TimeZones" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  def page = Nokogiri::HTML(response.body)

  it "redirects PATCH /user/time_zone without a session to the login" do
    patch user_time_zone_path, params: { user: { time_zone: "America/New_York" } }

    expect(response).to redirect_to(new_session_path)
  end

  context "when signed in" do
    before { sign_in(user) }

    it "stores the time zone on the user" do
      patch user_time_zone_path, params: { user: { time_zone: "America/New_York" } }

      expect(user.reload.time_zone).to eq("America/New_York")
      expect(response).to redirect_to(edit_user_path)
      expect(flash[:notice]).to eq("Time zone updated.")
    end

    it "refuses an unknown time zone" do
      patch user_time_zone_path, params: { user: { time_zone: "Mars/Olympus_Mons" } }

      expect(user.reload.time_zone).to eq("Europe/Berlin")
      expect(flash[:alert]).to include("Time zone")
    end

    it "offers the zones on the account page, the user's own selected" do
      user.update!(time_zone: "Asia/Tokyo")

      get edit_user_path

      expect(page.at_css("select#user_time_zone option[selected]")["value"]).to eq("Asia/Tokyo")
      expect(page.css("select#user_time_zone option").map { it["value"] }).to include("Europe/Berlin", "America/Los_Angeles")
    end
  end

  # 23:30 UTC: already the 17th in Berlin, still the 16th in Los Angeles
  describe "today" do
    let(:member) { create(:member, user:) }
    let(:project) { create(:project, org: member.org) }

    before do
      create(:participant, member:, project:)
      sign_in(user)
travel_to(Time.utc(2026, 10, 16, 23, 30))
    end




    it "is the date in Europe/Berlin by default" do
      get root_path

      expect(response).to redirect_to(edit_day_path(member.org, project, Date.new(2026, 10, 17)))
    end

    it "is the date in the user's time zone" do
      user.update!(time_zone: "America/Los_Angeles")

      get root_path

      expect(response).to redirect_to(edit_day_path(member.org, project, Date.new(2026, 10, 16)))
    end

    it "locks the past by the user's date" do
      post entries_path(member.org, project), params: { entry: { date: "2026-10-16", log: "late" } }

      expect(project.entries.count).to eq(0)
    end

    it "keeps the user's today open while it is already tomorrow in Berlin" do
      user.update!(time_zone: "America/Los_Angeles")

      post entries_path(member.org, project), params: { entry: { date: "2026-10-16", log: "late" } }

      expect(project.entries.count).to eq(1)
    end

    it "leaves the app's zone as it was after the request" do
      user.update!(time_zone: "America/Los_Angeles")

      get root_path

      expect(Time.zone.name).to eq("Europe/Berlin")
    end
  end
end
