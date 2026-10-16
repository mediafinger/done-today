require "rails_helper"

RSpec.describe "Orgs::Weeks" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in(participant.member.user) }

  describe "GET /weeks/:week" do
    def entry_on(date, log)
      day = Day.find_or_create_by!(project:, date: Date.parse(date))
      create(:entry, day:, member:, log:)
    end

    def read_week(week)
      get week_path(org, project, week)
      Nokogiri::HTML(response.body)
    end

    it "lists the entries of the ISO week, newest day first" do
      entry_on("2026-09-13", "sunday before")
      entry_on("2026-09-14", "monday of w38")
      entry_on("2026-09-20", "sunday of w38")
      entry_on("2026-09-21", "monday after")

      text = read_week("2026-W38").at_css("#entries").text

      expect(text).to match(/sunday of w38.*monday of w38/m)
      expect(text).not_to include("before")
      expect(text).not_to include("after")
    end

    it "shows each member's total on the first line of every day" do
      entry_on("2026-09-15", "start@09:00 end@14:30")
      entry_on("2026-09-15", "wrote code")
      entry_on("2026-09-14", "start@10:00 end@12:00")

      rows = read_week("2026-W38").css("#entries .entry-heading-row").map { it.text.squish }

      expect(rows).to eq([ "2026-09-15 #{member.name} (5h30m)", "2026-09-14 #{member.name} (2h)" ])
    end

    it "names the project and the week in the headline, without a project column" do
      entry_on("2026-09-14", "monday of w38")

      page = read_week("2026-W38")

      expect(page.at_css(".spacing-grid h2").text.squish).to eq("#{project.name} 2026 / w38")
      expect(page.css("#entries .entry-group-heading").map { it.text.squish }).to eq([ "2026-09-14", member.name ])
    end

    it "links to the previous and the next week, across the turn of the year" do
      arrows = read_week("2026-W53").css(".spacing-grid .right a")

      expect(arrows.map(&:text)).to eq(%w[⬅️ ➡️])
      expect(arrows.map { it["href"] }).to eq([
        week_path(org, project, "2026-W52"),
        week_path(org, project, "2027-W01")
      ])
    end

    it "stays read-only" do
      entry_on("2026-09-14", "monday of w38")

      expect(read_week("2026-W38").at_css("form")).to be_nil
    end

    it "sends a week it cannot read back to the project's weeks" do
      read_week("2026-W99")

      expect(response).to redirect_to(project_path(org, project, view: "weeks"))
      expect(flash[:alert]).to eq("2026-W99 is not a week, it has to look like 2026-W39")
    end
  end
end
