require "rails_helper"

RSpec.describe "Orgs::Tags" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in(participant.member.user) }

  describe "GET /tags/:tag" do
    let(:colleague) { create(:participant, project:).member }

    def entry_on(date, log, by: member, status: "done")
      day = Day.find_or_create_by!(project:, date: Date.parse(date))
      create(:entry, day:, member: by, log:, status:)
    end

    def read_tag(tag)
      get tag_path(org, project, tag)
      Nokogiri::HTML(response.body)
    end

    # the date and member heading of every listed line
    def lines(page)
      page.css("#entries li").map { |line| line.css(".entry-group-heading").map { it.text.squish } }
    end

    it "names the project and the tag in the headline" do
      expect(read_tag("handover").at_css(".spacing-grid h2").text.squish).to eq("#{project.name} #handover")
    end

    it "lists the tagged entries newest first, showing date and member only where they change" do
      entry_on("2026-09-01", "first #handover")
      entry_on("2026-09-03", "third #handover", by: colleague)
      entry_on("2026-09-03", "fourth #handover", by: colleague)
      entry_on("2026-09-02", "untagged")

      page = read_tag("handover")

      expect(page.css("#entries li").map { it.text.squish }).to all(include("handover"))
      expect(lines(page)).to eq([
        [ "2026-09-03", colleague.name ],
        [],
        [ "2026-09-01", member.name ]
      ])
      expect(page.at_css("#entries").text).to match(/fourth.*third.*first/m)
    end

    it "puts the headings of a group on a row of their own, above its entries" do
      entry_on("2026-09-01", "first #handover")
      entry_on("2026-09-01", "second #handover")

      page = read_tag("handover")
      heading_rows = page.css("#entries .entry-heading-row")

      expect(heading_rows.map { it.text.squish }).to eq([ "2026-09-01 #{member.name}" ])
      expect(heading_rows.css(".btn-done")).to be_empty
      expect(page.css("#entries .entry-grid:not(.entry-heading-row)").map { it.text.squish })
        .to all(match(/handover todo doing done\z/))
    end

    it "shows the status of each entry" do
      entry_on("2026-09-01", "waiting #handover", status: "todo")

      expect(read_tag("handover").at_css("#entries .btn-todo").text).to eq("todo")
    end

    it "leaves out entries of other projects" do
      other = create(:participant, project: create(:project, org:), member:).project
      create(:entry, day: create(:day, project: other), member:, log: "elsewhere #handover")

      expect(read_tag("handover").at_css("#entries").text).not_to include("elsewhere")
    end

    it "finds the tag however it is written in the URL" do
      entry_on("2026-09-01", "done #Handover")

      expect(lines(read_tag("#HandOver")).size).to eq(1)
    end

    it "stays read-only" do
      entry_on(Time.zone.today.iso8601, "today #handover")

      page = read_tag("handover")

      expect(page.at_css("form")).to be_nil
      expect(page.to_html).not_to include("add or edit")
    end

    it "finds a tag with a slash in it" do
      entry_on("2026-09-01", "started #feature/login")

      expect(read_tag("feature/login").at_css("#entries").text).to include("started")
    end

    it "shows the entries of another readable project" do
      other = create(:participant, project: create(:project, org:), member:).project
      create(:entry, day: create(:day, project: other), member:, log: "elsewhere #handover")

      get tag_path(org, other, "handover")
      page = Nokogiri::HTML(response.body)

      expect(page.at_css(".spacing-grid h2").text.squish).to eq("#{other.name} #handover")
      expect(page.at_css("#entries").text).to include("elsewhere")
    end

    it "says so when nothing carries the tag" do
      expect(read_tag("nothing").text).to include("No entries are tagged #nothing yet.")
    end
  end

  describe "GET /tags" do
    include ActiveSupport::Testing::TimeHelpers

    let(:colleague) { create(:participant, project:, member: create(:member, org:, name: "Bert")).member }

    before { member.update!(name: "anna") }

    def entry_on(date, log, by: member)
      day = Day.find_or_create_by!(project:, date: Date.parse(date))
      create(:entry, day:, member: by, log:)
    end

    def read_tag_times(month = nil, **period)
      get tags_path(org, project, month:, **period)
      Nokogiri::HTML(response.body)
    end

    # each tag's rows, as the cells read
    def table(page)
      page.css("#tag-times tbody").map { |group| group.css("tr").map { |row| row.css("th, td").map { it.text.squish } } }
    end

    it "sums each tag of the month alphabetically, then the time per participant" do
      entry_on("2026-10-05", "#review for~30m")
      entry_on("2026-10-05", "#call for~40m", by: colleague)
      entry_on("2026-10-06", "#Call from@10:00 to@11:30")

      expect(table(read_tag_times("2026-10"))).to eq([
        [ [ "#call", "Total", "2h10m" ], [ "anna", "1h30m" ], [ "Bert", "40m" ] ],
        [ [ "#review", "Total", "30m" ], [ "anna", "30m" ] ]
      ])
    end

    it "links every tag to its entries" do
      entry_on("2026-10-05", "#call for~40m")

      link = read_tag_times("2026-10").at_css("#tag-times tbody th a")

      expect(link["href"]).to eq(tag_path(org, project, "call"))
    end

    it "leaves out other months and other projects" do
      entry_on("2026-09-30", "#call for~1h")
      entry_on("2026-11-01", "#call for~2h")
      entry_on("2026-10-31", "#call for~3h")
      other = create(:participant, project: create(:project, org:), member:).project
      create(:entry, day: create(:day, project: other, date: Date.new(2026, 10, 5)), member:, log: "#call for~4h")

      expect(table(read_tag_times("2026-10"))).to eq([ [ [ "#call", "Total", "3h" ], [ "anna", "3h" ] ] ])
    end

    it "names the project and the month, and links the months before and after" do
      page = read_tag_times("2026-01")

      expect(page.at_css(".spacing-grid h2").text.squish).to eq("#{project.name} tag times 2026-01")
      expect(page.css(".spacing-grid .right a").map { it["href"] }).to eq([
        tags_path(org, project, month: "2025-12"),
        tags_path(org, project, month: "2026-02")
      ])
    end

    it "shows the current month in the user's time zone without a month" do
      member.user.update!(time_zone: "Europe/Berlin")

      travel_to(Time.utc(2026, 10, 31, 23, 30)) do # already November in Berlin
        expect(read_tag_times.at_css(".spacing-grid h2").text).to include("2026-11")
      end
    end

    it "sends a month it cannot read back to the current one" do
      get tags_path(org, project, month: "2026-13")

      expect(response).to redirect_to(tags_path(org, project))
      expect(flash[:alert]).to eq("2026-13 is not a month, it has to look like 2026-09")
    end

    it "says so when no tag has a time in the month" do
      entry_on("2026-10-05", "for~1h without a tag")

      page = read_tag_times("2026-10")

      expect(page.at_css("#tag-times")).to be_nil
      expect(page.at_css("main").text.squish).to include("No tag times in 2026-10.")
    end

    it "sums the tag times of a week, Monday to Sunday" do
      entry_on("2026-10-11", "#call for~1h")
      entry_on("2026-10-12", "#call for~2h")
      entry_on("2026-10-18", "#call for~3h")
      entry_on("2026-10-19", "#call for~4h")

      page = read_tag_times(week: "2026-W42")

      expect(page.at_css(".spacing-grid h2").text).to include("2026-W42")
      expect(table(page)).to eq([ [ [ "#call", "Total", "5h" ], [ "anna", "5h" ] ] ])
    end

    it "sums the tag times of a year" do
      entry_on("2025-12-31", "#call for~1h")
      entry_on("2026-01-01", "#call for~2h")
      entry_on("2026-12-31", "#call for~3h")

      page = read_tag_times(year: "2026")

      expect(page.at_css(".spacing-grid h2").text).to include("2026")
      expect(table(page)).to eq([ [ [ "#call", "Total", "5h" ], [ "anna", "5h" ] ] ])
    end

    it "links the periods of the same kind before and after" do
      page = read_tag_times(week: "2026-W01")

      expect(page.css(".spacing-grid .right a").map { it["href"] }).to eq([
        tags_path(org, project, week: "2025-W52"),
        tags_path(org, project, week: "2026-W02")
      ])
    end

    it "switches between week, month and year around the period shown, marking the current kind" do
      page = read_tag_times("2026-03")
      links = page.css("#period-kinds a")

      expect(links.map { it["href"] }).to eq([
        tags_path(org, project, week: "2026-W09"),
        tags_path(org, project, month: "2026-03"),
        tags_path(org, project, year: "2026")
      ])
      expect(links.map { it["aria-current"] }).to eq([ nil, "page", nil ])
    end

    it "sends a week or a year it cannot read back to the current month" do
      [ { week: "2026-W99" }, { year: "26" } ].each do |period|
        get tags_path(org, project, **period)

        expect(response).to redirect_to(tags_path(org, project))
        expect(flash[:alert]).to include(period.values.first)
      end
    end

    context "with one participant" do
      before do
        entry_on("2026-10-05", "#call for~40m")
        entry_on("2026-10-05", "#review for~30m")
        entry_on("2026-10-06", "#call for~1h", by: colleague)
        entry_on("2026-10-07", "#retro for~1h", by: colleague)
      end

      it "sums only that participant's tag times, by tag" do
        page = read_tag_times("2026-10", member_id: colleague.id)

        expect(page.at_css(".spacing-grid h2").text).to include(colleague.name)
        expect(table(page)).to eq([ [ [ "#call", "1h" ] ], [ [ "#retro", "1h" ] ] ])
      end

      it "is linked from each participant's name in the report of everyone" do
        links = read_tag_times("2026-10").css("#tag-times tbody td a")

        expect(links.map { [ it.text, it["href"] ] }.uniq).to contain_exactly(
          [ "anna", tags_path(org, project, month: "2026-10", member_id: member.id) ],
          [ "Bert", tags_path(org, project, month: "2026-10", member_id: colleague.id) ]
        )
      end

      it "keeps the participant when switching periods, and links back to everyone" do
        page = read_tag_times("2026-03", member_id: colleague.id)
        hrefs = page.css(".spacing-grid .right a, #period-kinds a").map { it["href"] }

        expect(hrefs).to all(include("member_id=#{colleague.id}"))
        expect(page.at_css("#everyone")["href"]).to eq(tags_path(org, project, month: "2026-03"))
      end

      it "doesn't know members of other orgs" do
        get tags_path(org, project, member_id: create(:member).id)

        expect(response).to have_http_status(:not_found)
      end
    end

    it "is linked from the project page" do
      get project_path(org, project)

      expect(Nokogiri::HTML(response.body).at_css(".project-views a[href='#{tags_path(org, project)}']").text).to eq("tag times")
    end
  end
end
