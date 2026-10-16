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
end
