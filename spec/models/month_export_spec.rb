require "rails_helper"
require "csv"

RSpec.describe MonthExport do
  let(:org) { create(:org, name: "Codurance AG") }
  let(:project) { create(:project, org:, name: "2026 v1") }
  let(:anna) { create(:member, org:, name: "anna") }
  let(:bert) { create(:member, org:, name: "Bert") }
  let(:month) { Date.new(2026, 9, 1) }

  def entry(date, log, by: anna)
    day = Day.find_or_create_by!(project:, date: Date.parse(date))
    create(:entry, day:, member: by, log:)
  end

  def rows(of: month)
    CSV.parse(described_class.new(project:, month: of).to_csv, headers: true)
  end

  describe "#to_csv" do
    it "names the columns" do
      expect(rows.headers).to eq(%w[org project member hours tags])
    end

    it "writes one line per member of the month, by member name" do
      entry("2026-09-02", "start@09:00 end@17:00", by: bert)
      entry("2026-09-01", "start@09:00 end@12:30")

      expect(rows.map { it["member"] }).to eq(%w[anna Bert])
      expect(rows.map { [ it["org"], it["project"] ] }).to all(eq([ "Codurance AG", "2026 v1" ]))
    end

    it "totals the hours of the month, breaks already subtracted" do
      entry("2026-09-01", "start@09:00 end@17:00")
      entry("2026-09-01", "#break for~30m")
      entry("2026-09-02", "start@09:00 end@12:00")

      expect(rows.first["hours"]).to eq("10.5")
    end

    it "writes 0.0 for a member who logged no times" do
      entry("2026-09-01", "wrote some code")

      expect(rows.first["hours"]).to eq("0.0")
    end

    it "lists the tags, most used first, without #break" do
      entry("2026-09-01", "#handover #review")
      entry("2026-09-02", "#review again")
      entry("2026-09-03", "#break for~30m")
      entry("2026-09-04", "#review and #alpha")

      expect(rows.first["tags"]).to eq("#review #alpha #handover")
    end

    it "keeps at most 20 tags" do
      25.times { |n| entry("2026-09-01", "tag number #t#{n.to_s.rjust(2, '0')}") }
      entry("2026-09-02", "#t00 again")

      tags = rows.first["tags"].split

      expect(tags.size).to eq(20)
      expect(tags.first).to eq("#t00")
    end

    it "leaves out the entries of other months and projects" do
      entry("2026-08-31", "start@09:00 end@17:00")
      entry("2026-10-01", "start@09:00 end@17:00")
      other = create(:project, org:)
      create(:entry, day: create(:day, project: other, date: Date.new(2026, 9, 5)), member: anna, log: "start@09:00 end@17:00")
      entry("2026-09-30", "start@09:00 end@10:00")

      expect(rows.map { it["hours"] }).to eq([ "1.0" ])
    end

    it "is only the headers for a month without entries" do
      expect(rows).to be_empty
    end
  end

  describe "#filename" do
    it "names org, project and month, and ends on done for a month that is over" do
      expect(described_class.new(project:, month: Date.new(2026, 8, 1)).filename)
        .to eq("codurance-ag_2026-v1_2026_08_done.csv")
    end

    it "ends on doing while the month is running" do
      expect(described_class.new(project:, month: Time.zone.today).filename).to end_with("_doing.csv")
    end

    it "ends on todo for a month still to come" do
      expect(described_class.new(project:, month: Time.zone.today + 2.months).filename).to end_with("_todo.csv")
    end

    it "takes any day of the month" do
      expect(described_class.new(project:, month: Date.new(2026, 8, 17)).filename).to include("2026_08")
    end
  end
end
