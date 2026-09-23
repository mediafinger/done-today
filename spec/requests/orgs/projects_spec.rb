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

  describe "GET /projects/:slug?view=weeks" do
    def show_weeks
      get project_path(project.slug, view: "weeks")
      Nokogiri::HTML(response.body)
    end

    before do
      member.update!(name: "Zoe")
      anna = create(:participant, project:, member: create(:member, org:, name: "Anna")).member
      entry_on("2026-09-21", "start@09:00 #handover")
      entry_on("2026-09-21", "#break for~30m")
      entry_on("2026-09-21", "end@17:30 reviewed #PR123")
      entry_on("2026-09-23", "wrote code #handover", by: anna)
      entry_on("2026-09-14", "start@10:00 end@12:00")
    end

    it "puts each week on its own line, newest first, linked to the week's entries" do
      headings = show_weeks.css(".period h3 a")

      expect(headings.map(&:text)).to eq([ "2026 / w39", "2026 / w38" ])
      expect(headings.first["href"]).to eq(entries_path(week: "2026-W39", project_id: project.id))
    end

    it "lists the members of the week alphabetically, with their total and tags" do
      lines = show_weeks.css(".period").first.css("li").map { it.text.squish }

      expect(lines).to eq([ "Anna #handover", "Zoe (8h) #break #handover #pr123" ])
    end

    it "links the members and their tags" do
      line = show_weeks.css(".period").first.css("li").last

      expect(line.at_css("a")["href"]).to eq(entries_path(member_id: member.id, project_id: project.id))
      expect(line.css("a.tag").map { it["href"] }).to eq(
        %w[break handover pr123].map { entries_path(tag: it, mode: "read") }
      )
    end

    it "shows neither the logs nor any status buttons" do
      page = show_weeks

      expect(page.text).not_to include("reviewed")
      expect(page.css("#{Entry::STATES.map { ".btn-#{it}" }.join(', ')}")).to be_empty
    end

    it "marks the current view in the switcher" do
      expect(show_weeks.at_css(".project-views [aria-current=page]").text).to eq("weeks")
    end
  end

  describe "GET /projects/:slug?view=months" do
    def show_months
      get project_path(project.slug, view: "months")
      Nokogiri::HTML(response.body)
    end

    before do
      member.update!(name: "Zoe")
      anna = create(:participant, project:, member: create(:member, org:, name: "Anna")).member
      entry_on("2026-09-01", "start@09:00 end@17:00 #handover")
      entry_on("2026-09-30", "start@09:00 #break for~1h end@12:00 reviewed #PR123")
      entry_on("2026-09-15", "wrote code #roadmap", by: anna)
      entry_on("2026-08-31", "start@10:00 end@12:00 #onboarding")
    end

    it "puts each month on its own line, newest first, with its first and last calendar week" do
      expect(show_months.css(".period h3").map { it.text.squish }).to eq([ "2026-09 (w36 - w40)", "2026-08 (w31 - w36)" ])
    end

    it "links the month's first and last calendar week to their entries" do
      links = show_months.css(".period h3").first.css("a")

      expect(links.map { it["href"] }).to eq([
        entries_path(week: "2026-W36", project_id: project.id), entries_path(week: "2026-W40", project_id: project.id)
      ])
    end

    it "lists the members of the month alphabetically, with their total and the month's tags" do
      lines = show_months.css(".period").first.css("li").map { it.text.squish }

      expect(lines).to eq([ "Anna #roadmap", "Zoe (10h) #break #handover #pr123" ])
    end

    it "links the members and their tags" do
      line = show_months.css(".period").first.css("li").last

      expect(line.at_css("a")["href"]).to eq(entries_path(member_id: member.id, project_id: project.id))
      expect(line.css("a.tag").map { it["href"] }).to eq(
        %w[break handover pr123].map { entries_path(tag: it, mode: "read") }
      )
    end

    it "shows neither the logs nor any status buttons" do
      page = show_months

      expect(page.text).not_to include("reviewed")
      expect(page.css("#{Entry::STATES.map { ".btn-#{it}" }.join(', ')}")).to be_empty
    end
  end

  describe "GET /projects/:slug/validate_times" do
    def validate
      get validate_times_project_path(project.slug)
      Nokogiri::HTML(response.body)
    end

    it "offers the check from the project page" do
      expect(show_project.at_css(%(a[href="#{validate_times_project_path(project.slug)}"])).text).to eq("validate times")
    end

    it "lists the days that do not add up, newest first, with the reason" do
      entry_on("2026-09-21", "start@09:00 kickoff")
      entry_on("2026-09-20", "end@17:00 wrapped up")
      entry_on("2026-09-19", "start@09:00 end@17:00 a sound day")

      blocks = validate.css(".period").map { it.text.squish }

      expect(blocks).to eq([
        "2026-09-21 #{member.name} start@09:00 has no end@",
        "2026-09-20 #{member.name} end@17:00 has no start@"
      ])
    end

    it "links each day to its unlocked edit page" do
      entry_on("2026-09-21", "start@09:00 kickoff")

      expect(validate.at_css(".period h3 a")["href"])
        .to eq(entries_path(date: "2026-09-21", mode: "edit", unlocked: "1", project_id: project.id))
    end

    it "reports a day without any time markup" do
      entry_on("2026-09-21", "wrote some code")

      expect(validate.at_css(".period").text.squish).to include("no time information given")
    end

    it "says so when every day adds up" do
      entry_on("2026-09-21", "start@09:00 end@17:00 a sound day")

      expect(validate.text).to include("Every day with entries adds up.")
    end

    it "leaves out the days of other projects" do
      other = create(:participant, project: create(:project, org:), member:).project
      create(:entry, day: create(:day, project: other, date: Date.new(2026, 9, 21)), member:, log: "start@09:00 elsewhere")

      expect(validate.text).to include("Every day with entries adds up.")
    end
  end

  it "falls back to the days for an unknown view" do
    entry_on("2026-09-21", "wrote some code")

    get project_path(project.slug, view: "decades")

    expect(response.body).to include("wrote some code")
  end
end
