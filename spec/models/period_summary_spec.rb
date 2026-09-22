require "rails_helper"

RSpec.describe PeriodSummary do
  let(:project) { create(:project) }
  let(:anna) { create(:member, org: project.org, name: "anna") }
  let(:bert) { create(:member, org: project.org, name: "Bert") }

  def entry(date, log, by: anna)
    day = Day.find_or_create_by!(project:, date: Date.parse(date))
    create(:entry, day:, member: by, log:)
  end

  def weeks
    described_class.weeks(project.entries.includes(:member, :day))
  end

  describe ".weeks" do
    it "groups by ISO week, newest week first, each starting on its Monday" do
      entry("2026-09-14", "log a") # Monday, w38
      entry("2026-09-20", "log b") # Sunday, w38
      entry("2026-09-21", "log c") # Monday, w39

      expect(weeks.map(&:start)).to eq([ Date.new(2026, 9, 21), Date.new(2026, 9, 14) ])
    end

    it "keeps days around New Year in the ISO week they belong to" do
      entry("2026-12-31", "log a") # Thursday, 2026-w53
      entry("2027-01-03", "log b") # Sunday, still 2026-w53

      expect(weeks.map(&:start)).to eq([ Date.new(2026, 12, 28) ])
    end
  end

  describe "#rows" do
    it "has one row per member, in alphabetical order regardless of case" do
      entry("2026-09-21", "log a", by: bert)
      entry("2026-09-22", "log b", by: anna)

      expect(weeks.first.rows.map { it.member.name }).to eq(%w[anna Bert])
    end

    it "adds up the member's day totals, each already minus its breaks" do
      entry("2026-09-21", "start@09:00")
      entry("2026-09-21", "#break for~1h")
      entry("2026-09-21", "end@17:00")
      entry("2026-09-22", "start@09:00 end@13:30")

      expect(weeks.first.rows.first.total_minutes).to eq((7 * 60) + (4.5 * 60))
    end

    it "leaves a day without a total out of the sum" do
      entry("2026-09-21", "start@09:00 end@12:00")
      entry("2026-09-22", "start@09:00")

      expect(weeks.first.rows.first.total_minutes).to eq(180)
    end

    it "has no total when no day of the week has one" do
      entry("2026-09-21", "wrote code")

      expect(weeks.first.rows.first.total_minutes).to be_nil
    end

    it "keeps the members' totals apart" do
      entry("2026-09-21", "start@09:00 end@10:00", by: anna)
      entry("2026-09-21", "start@09:00 end@12:00", by: bert)

      expect(weeks.first.rows.map(&:total_minutes)).to eq([ 60, 180 ])
    end

    it "lists each member's tags of the week once, sorted" do
      entry("2026-09-21", "#Review and #handover")
      entry("2026-09-22", "#handover again")
      entry("2026-09-22", "#other", by: bert)

      expect(weeks.first.rows.map(&:tags)).to eq([ %w[handover review], %w[other] ])
    end
  end
end
