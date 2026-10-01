require "rails_helper"
require "csv"

RSpec.describe DaysExport do
  let(:org) { create(:org, name: "Codurance AG") }
  let(:project) { create(:project, org:, name: "2026 v1") }
  let(:anna) { create(:member, org:, name: "Anna Smith") }
  let(:bert) { create(:member, org:, name: "Bert") }
  let(:month) { Date.new(2026, 9, 1) }

  def entry(date, log, by: anna)
    day = Day.find_or_create_by!(project:, date: Date.parse(date))
    create(:entry, day:, member: by, log:)
  end

  def export(of: month)
    described_class.new(project:, member: anna, month: of)
  end

  def rows(of: month)
    CSV.parse(export(of:).to_csv, headers: true)
  end

  describe "#to_csv" do
    it "names the columns" do
      expect(rows.headers).to eq(%w[org project member date hours tags])
    end

    it "writes one line per day of the member, oldest first" do
      entry("2026-09-30", "start@09:00 end@14:30 #frame1 #adr #cms")
      entry("2026-09-02", "start@09:00 end@17:00")

      expect(rows.map(&:fields)).to eq([
        [ "Codurance AG", "2026 v1", "Anna Smith", "2026-09-02", "8.0", "" ],
        [ "Codurance AG", "2026 v1", "Anna Smith", "2026-09-30", "5.5", "#adr #cms #frame1" ]
      ])
    end

    it "totals the hours of each day, breaks already subtracted, without #break in the tags" do
      entry("2026-09-01", "start@09:00 end@17:00 #review")
      entry("2026-09-01", "#break for~30m")

      expect(rows.first["hours"]).to eq("7.5")
      expect(rows.first["tags"]).to eq("#review")
    end

    it "leaves out other members, other months and other projects" do
      entry("2026-09-01", "start@09:00 end@17:00", by: bert)
      entry("2026-08-31", "start@09:00 end@17:00")
      entry("2026-10-01", "start@09:00 end@17:00")
      other = create(:project, org:)
      create(:entry, day: create(:day, project: other, date: Date.new(2026, 9, 5)), member: anna, log: "start@09:00 end@17:00")
      entry("2026-09-15", "start@09:00 end@10:00")

      expect(rows.map { [ it["date"], it["hours"] ] }).to eq([ [ "2026-09-15", "1.0" ] ])
    end

    it "is only the headers for a month without entries" do
      expect(rows).to be_empty
    end
  end

  describe "#filename" do
    it "names org, project, member and the first and last day of the CSV" do
      entry("2026-09-03", "start@09:00 end@17:00")
      entry("2026-09-30", "start@09:00 end@17:00")

      expect(export.filename).to eq("codurance-ag_2026-v1_anna-smith_2026-09-03_2026-09-30.csv")
    end

    it "falls back to the first and last day of the month without entries" do
      expect(export.filename).to eq("codurance-ag_2026-v1_anna-smith_2026-09-01_2026-09-30.csv")
    end
  end
end
