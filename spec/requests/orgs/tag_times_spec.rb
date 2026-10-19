require "rails_helper"
require "csv"

RSpec.describe "Orgs::TagTimes" do
  let(:org) { create(:org) }
  let(:website) { create(:project, org:, name: "Website") }
  let(:mobile) { create(:project, org:, name: "Mobile") }
  let(:anna) { create(:member, org:, name: "anna") }
  let(:bert) { create(:member, org:, name: "Bert") }

  before { sign_in(create(:member, :manager, org:).user) }

  def entry_on(date, log, by: anna, project: website)
    day = Day.find_or_create_by!(project:, date: Date.parse(date))
    create(:entry, day:, member: by, log:)
  end

  def read_tag_times(**params)
    get org_tags_path(org, **params)
    Nokogiri::HTML(response.body)
  end

  # each tag's rows, as the cells read
  def table(page)
    page.css("#tag-times tbody").map { |group| group.css("tr").map { |row| row.css("th, td").map { it.text.squish } } }
  end

  describe "GET /:org/tags" do
    it "sums each tag across the org's projects, then the time per member" do
      entry_on("2026-10-05", "#call for~40m")
      entry_on("2026-10-06", "#call for~1h", project: mobile)
      entry_on("2026-10-07", "#call for~30m", by: bert, project: mobile)
      entry_on("2026-10-08", "#review for~15m", by: bert)

      expect(table(read_tag_times(month: "2026-10"))).to eq([
        [ [ "#call", "Total", "2h10m" ], [ "anna", "1h40m" ], [ "Bert", "30m" ] ],
        [ [ "#review", "Total", "15m" ], [ "Bert", "15m" ] ]
      ])
    end

    it "includes archived projects and archived members" do
      entry_on("2026-10-05", "#call for~1h", by: bert, project: mobile)
      mobile.archive!
      bert.archive!

      expect(table(read_tag_times(month: "2026-10"))).to eq([ [ [ "#call", "Total", "1h" ], [ "Bert", "1h" ] ] ])
    end

    it "leaves out other periods and other orgs" do
      entry_on("2026-10-11", "#call for~1h")
      entry_on("2026-10-12", "#call for~2h")
      other = create(:project)
      create(:entry, day: create(:day, project: other, date: Date.new(2026, 10, 12)), member: create(:member, org: other.org),
             log: "#call for~4h")

      expect(table(read_tag_times(week: "2026-W42"))).to eq([ [ [ "#call", "Total", "2h" ], [ "anna", "2h" ] ] ])
    end

    it "names the org and the period, and links the periods around it" do
      page = read_tag_times(month: "2026-03")

      expect(page.at_css(".spacing-grid h2").text).to include(org.name, "2026-03")
      expect(page.css(".spacing-grid .right a").map { it["href"] }).to eq([
        org_tags_path(org, month: "2026-02"), org_tags_path(org, month: "2026-04")
      ])
      expect(page.css("#period-kinds a").map { it["href"] }).to eq([
        org_tags_path(org, week: "2026-W09"), org_tags_path(org, month: "2026-03"), org_tags_path(org, year: "2026")
      ])
    end

    it "doesn't link the tags to a project" do
      entry_on("2026-10-05", "#call for~1h")

      expect(read_tag_times(month: "2026-10").at_css("#tag-times th a")).to be_nil
    end

    it "sends a period it cannot read back to the current month" do
      get org_tags_path(org, month: "2026-13")

      expect(response).to redirect_to(org_tags_path(org))
      expect(flash[:alert]).to include("2026-13")
    end

    it "says so when there are no tag times" do
      expect(read_tag_times(month: "2026-10").at_css("#tag-times")).to be_nil
    end

    context "with one member" do
      before do
        entry_on("2026-10-05", "#call for~40m")
        entry_on("2026-10-06", "#call for~1h", by: bert, project: mobile)
        entry_on("2026-10-07", "#retro for~20m", by: bert)
      end

      it "sums only that member's tag times across the projects" do
        page = read_tag_times(month: "2026-10", member_id: bert.id)

        expect(page.at_css(".spacing-grid h2").text).to include(bert.name)
        expect(table(page)).to eq([ [ [ "#call", "1h" ] ], [ [ "#retro", "20m" ] ] ])
      end

      it "is linked from each member's name, and links back to everyone" do
        links = read_tag_times(month: "2026-10").css("#tag-times tbody td a")

        expect(links.map { [ it.text, it["href"] ] }.uniq).to contain_exactly(
          [ "anna", org_tags_path(org, month: "2026-10", member_id: anna.id) ],
          [ "Bert", org_tags_path(org, month: "2026-10", member_id: bert.id) ]
        )
        expect(read_tag_times(month: "2026-10", member_id: bert.id).at_css("#everyone")["href"])
          .to eq(org_tags_path(org, month: "2026-10"))
      end

      it "takes an archived member" do
        bert.archive!

        expect(table(read_tag_times(month: "2026-10", member_id: bert.id)).size).to eq(2)
      end

      it "doesn't know members of other orgs" do
        get org_tags_path(org, member_id: create(:member).id)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "as CSV" do
      before do
        entry_on("2026-10-05", "#call for~40m")
        entry_on("2026-10-06", "#call for~1h", project: mobile)
        entry_on("2026-10-07", "#retro for~20m", by: bert)
        entry_on("2026-11-02", "#call for~2h")
      end

      def export(**params)
        get org_tags_path(org, format: :csv, **params)
        CSV.parse(response.body, headers: true)
      end

      it "sends the period, a line per tag, member and project" do
        rows = export(month: "2026-10")

        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("#{org.name.parameterize}_tag-times_2026-10.csv")
        expect(rows.map { it.to_h.values_at("project", "period", "tag", "member", "minutes") }).to eq([
          [ "Mobile", "2026-10", "#call", "anna", "60" ],
          [ "Website", "2026-10", "#call", "anna", "40" ],
          [ "Website", "2026-10", "#retro", "Bert", "20" ]
        ])
      end

      it "sends one member's lines, named after them" do
        rows = export(month: "2026-10", member_id: bert.id)

        expect(response.headers["Content-Disposition"]).to include("_bert_tag-times_2026-10.csv")
        expect(rows.map { it["member"] }).to eq([ "Bert" ])
      end

      it "is linked from the report, for the period and member shown" do
        everyone = read_tag_times(week: "2026-W42").at_css("#export-csv")["href"]
        one = read_tag_times(month: "2026-10", member_id: bert.id).at_css("#export-csv")["href"]

        expect([ everyone, one ]).to eq([
          org_tags_path(org, week: "2026-W42", format: :csv),
          org_tags_path(org, month: "2026-10", member_id: bert.id, format: :csv)
        ])
      end
    end

    it "is refused to a project lead" do
      sign_in(create(:participant, :lead, project: website).member.user)

      get org_tags_path(org)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
