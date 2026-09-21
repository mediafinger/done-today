require "rails_helper"

RSpec.describe "Orgs::Projects" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in_and_open(participant) }

  def entry_on(date, log, by: member)
    day = Day.find_or_create_by!(project:, date: Date.parse(date))
    create(:entry, day:, member: by, log:, status: "done")
  end

  def show_project(of: project)
    get project_path(of.slug)
    Nokogiri::HTML(response.body)
  end

  describe "GET /projects/:slug" do
    # the rows that separate the groups, holding date, member and total
    def heading_rows(page)
      page.css(".entry-heading-row").map { it.text.squish }
    end

    def totals(page)
      page.css(".entry-total").map { it.text.squish }.compact_blank
    end

    it "shows the total time per day next to the member, without an extra line" do
      member.update!(name: "Anna")
      zoe = create(:participant, project:, member: create(:member, org:, name: "Zoe")).member
      entry_on("2026-09-01", "start@10:00 end@12:30", by: zoe)
      entry_on("2026-09-01", "start@09:00 end@17:00")
      entry_on("2026-09-01", "#break for~1h")
      entry_on("2026-09-02", "start@08:00 end@09:30")

      page = show_project

      expect(heading_rows(page)).to contain_exactly(
        "2026-09-02 Anna (1h30m)", a_string_ending_with("Anna (7h)"), a_string_ending_with("Zoe (2h30m)")
      )
      expect(page.at_css(".time-info")).to be_nil
    end

    it "shows no total for a day without time markup" do
      entry_on("2026-09-01", "wrote some code #handover")

      expect(totals(show_project)).to be_empty
    end

    it "shows no total while a member's day has no end yet" do
      entry_on("2026-09-01", "start@09:00")

      expect(totals(show_project)).to be_empty
    end

    it "does not repeat the tag line of the day page" do
      entry_on("2026-09-01", "start@09:00 #handover")

      expect(show_project.at_css(".tag-info")).to be_nil
    end

    it "links the tags in the logs to the tag page" do
      entry_on("2026-09-01", "handed over #Handover")

      link = show_project.at_css("a.tag")

      expect(link.text).to eq("#Handover")
      expect(link["href"]).to eq(entries_path(tag: "handover", mode: "read"))
    end

    it "keeps the project in the tag link when it is not the current one" do
      other = create(:participant, project: create(:project, org:), member:).project
      create(:entry, day: create(:day, project: other), member:, log: "elsewhere #handover")

      link = show_project(of: other).at_css("a.tag")

      expect(link["href"]).to eq(entries_path(tag: "handover", mode: "read", project_id: other.id))
    end
  end
end
