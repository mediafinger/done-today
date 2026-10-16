require "rails_helper"

RSpec.describe "Orgs::Settings" do
  let(:participant) { create(:participant) }
  let(:org) { participant.org }
  let(:project) { participant.project }

  def links
    Nokogiri::HTML(response.body).css("main a").pluck("href")
  end

  def gear
    Nokogiri::HTML(response.body).css("nav a").find { it.text == "⚙" }["href"]
  end

  before { sign_in(participant.member.user) }

  describe "GET /settings" do
    it "lists the user's orgs, without the projects of any" do
      get settings_path

      expect(response).to have_http_status(:ok)
      expect(links).to include(org_settings_path(org))
      expect(links).not_to include(project_path(org, project))
    end

    it "is where the gear leads outside of an org" do
      get edit_user_path

      expect(gear).to eq(settings_path)
    end
  end

  describe "GET /:org/settings" do
    it "lists the projects of the org" do
      get org_settings_path(org)

      expect(links).to include(project_path(org, project))
    end

    it "is where the gear leads on the pages of the org" do
      get project_path(org, project)

      expect(gear).to eq(org_settings_path(org))
    end

    it "is a 404 for an org of someone else" do
      get org_settings_path(create(:org))

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "admin links" do
    let(:admin_links) { [ admin_home_path, admin_mission_control_jobs_path ] }

    it "are hidden from a user who is no admin" do
      get settings_path

      expect(links).not_to include(*admin_links)
    end

    it "are shown to an admin, on /settings and on /:org/settings" do
      participant.member.user.update!(admin: true)

      [ settings_path, org_settings_path(org) ].each do |path|
        get path

        expect(links).to include(*admin_links)
      end
    end
  end
end
