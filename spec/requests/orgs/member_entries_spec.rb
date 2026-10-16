require "rails_helper"

RSpec.describe "Orgs::MemberEntries" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in(participant.member.user) }

  describe "GET /members/:member_id/entries" do
    let(:colleague) { create(:participant, project:, member: create(:member, org:, name: "Anna")).member }

    def entry_on(date, log, by: member)
      day = Day.find_or_create_by!(project:, date: Date.parse(date))
      create(:entry, day:, member: by, log:)
    end

    def read_member(of)
      get member_entries_path(org, project, of)
      Nokogiri::HTML(response.body)
    end

    it "lists only that member's entries of the project, on every day" do
      entry_on("2026-09-01", "mine on the first")
      entry_on("2026-09-02", "mine on the second")
      entry_on("2026-09-02", "theirs", by: colleague)
      other = create(:participant, project: create(:project, org:), member:).project
      create(:entry, day: create(:day, project: other), member:, log: "elsewhere")

      text = read_member(member).at_css("#entries").text

      expect(text).to include("mine on the first", "mine on the second")
      expect(text).not_to include("theirs")
      expect(text).not_to include("elsewhere")
    end

    it "names project and member in the headline and only the date per line" do
      entry_on("2026-09-01", "mine")

      page = read_member(member)

      expect(page.at_css(".spacing-grid h2").text.squish).to eq("#{project.name} #{member.name}")
      expect(page.css("#entries .entry-group-heading").map { it.text.squish }).to eq([ "2026-09-01" ])
    end

    # ordered by status first, the done entries of every day came before the todos,
    #   so each day showed up twice
    it "keeps the entries of a day together, newest day first" do
      Day.create!(project:, date: Date.new(2026, 9, 1)).tap do |day|
        create(:entry, day:, member:, log: "first todo", status: "todo")
        create(:entry, day:, member:, log: "first done", status: "done")
      end
      create(:entry, day: Day.create!(project:, date: Date.new(2026, 9, 2)), member:, log: "second", status: "done")

      page = read_member(member)

      expect(page.css("#entries .entry-group-heading").map { it.text.squish }).to eq(%w[2026-09-02 2026-09-01])
      expect(page.at_css("#entries").text).to match(/second.*first done.*first todo/m)
    end

    it "links to the other members of the project" do
      colleague

      arrows = read_member(member).css(".spacing-grid .right a")

      expect(arrows.map { it["href"] }).to all(eq(member_entries_path(org, project, colleague)))
    end

    it "walks through the members by name, wrapping around" do
      colleague
      zoe = create(:participant, project:, member: create(:member, org:, name: "Zoe")).member
      member.update!(name: "Max")

      arrows = read_member(member).css(".spacing-grid .right a")

      expect(arrows.map { it["href"] }).to eq([
        member_entries_path(org, project, colleague),
        member_entries_path(org, project, zoe)
      ])
    end

    it "offers to add or edit today" do
      link = read_member(member).css(".spacing-grid a").find { it.text == "add or edit" }

      expect(link).to be_present
    end

    it "is a 404 for someone who is no member of the project" do
      read_member(create(:member, org:))

      expect(response).to have_http_status(:not_found)
    end
  end
end
