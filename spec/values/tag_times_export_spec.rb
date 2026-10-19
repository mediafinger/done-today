require "rails_helper"
require "csv"

RSpec.describe TagTimesExport do
  let(:org) { create(:org, name: "Codurance AG") }
  let(:project) { create(:project, org:, name: "2026 v1") }
  let(:anna) { create(:member, org:, name: "anna") }
  let(:bert) { create(:member, org:, name: "Bert") }
  let(:period) { ReportPeriod.new(:month, Date.new(2026, 10, 1)) }

  def entry(log, by: anna, date: "2026-10-05", on: project)
    day = Day.find_or_create_by!(project: on, date: Date.parse(date))
    create(:entry, day:, member: by, log:)
  end

  def export(entries: Entry.all, **options)
    described_class.new(entries:, org:, period:, **options)
  end

  def rows(**options)
    CSV.parse(export(**options).to_csv, headers: true)
  end

  describe "#to_csv" do
    it "names the columns" do
      expect(rows.headers).to eq(%w[org project period tag member hours minutes])
    end

    it "writes one line per tag and member, by tag, then member name" do
      entry("#review for~30m")
      entry("#call for~40m", by: bert)
      entry("#Call from@10:00 to@11:30")

      expect(rows.map { it.to_h.values_at("tag", "member", "minutes") }).to eq([
        [ "#call", "anna", "90" ], [ "#call", "Bert", "40" ], [ "#review", "anna", "30" ]
      ])
    end

    it "names org, project and period on every line" do
      entry("#call for~1h")
      entry("#review for~1h", by: bert)

      expect(rows.map { it.to_h.values_at("org", "project", "period") }).to all(eq([ "Codurance AG", "2026 v1", "2026-10" ]))
    end

    it "writes the hours rounded to two decimals next to the exact minutes" do
      entry("#call for~40m")

      expect(rows.first.to_h.values_at("hours", "minutes")).to eq([ "0.67", "40" ])
    end

    it "splits a tag by project, by project name, for entries of several projects" do
      other = create(:project, org:, name: "Alpha")
      entry("#call for~2h", on: other)
      entry("#call for~1h")

      expect(rows.map { it.to_h.values_at("project", "minutes") }).to eq([ [ "2026 v1", "60" ], [ "Alpha", "120" ] ])
    end

    it "keeps archived members" do
      entry("#call for~1h", by: bert)
      bert.archive!

      expect(rows.map { it["member"] }).to eq([ "Bert" ])
    end

    it "writes only the entries it is given" do
      entry("#call for~1h")
      entry("#call for~2h", by: bert)

      expect(rows(entries: Entry.where(member: bert)).map { it["member"] }).to eq([ "Bert" ])
    end

    it "writes the headers only without tag times" do
      entry("for~1h without a tag")

      expect(rows.size).to eq(0)
    end
  end

  describe "#filename" do
    it "is named after org, project and period" do
      expect(export(project:).filename).to eq("codurance-ag_2026-v1_tag-times_2026-10.csv")
    end

    it "names the member when it covers one" do
      week = ReportPeriod.new(:week, Date.new(2026, 10, 14))

      expect(described_class.new(entries: Entry.all, org:, period: week, project:, member: bert).filename)
        .to eq("codurance-ag_2026-v1_bert_tag-times_2026-W42.csv")
    end
  end
end
