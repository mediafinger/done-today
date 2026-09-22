require "rails_helper"

RSpec.describe EntriesHelper do
  describe "#format_clock" do
    it "pads hours and minutes" do
      expect(helper.format_clock(570)).to eq("09:30")
    end

    it "keeps hours past midnight instead of wrapping them" do
      expect(helper.format_clock(1530)).to eq("25:30")
    end

    it "stands in for a missing time" do
      expect(helper.format_clock(nil)).to eq("…")
    end
  end

  describe "#week_label" do
    it "names the ISO week and its year" do
      expect(helper.week_label(Date.new(2026, 9, 22))).to eq("2026 / w39")
    end

    it "pads the week number" do
      expect(helper.week_label(Date.new(2026, 1, 28))).to eq("2026 / w05")
    end

    it "takes the year the week belongs to, not the calendar year" do
      expect(helper.week_label(Date.new(2027, 1, 1))).to eq("2026 / w53")
    end
  end

  describe "#format_minutes" do
    it "writes a duration the way for~ reads it" do
      expect([ 90, 60, 45, 0 ].map { helper.format_minutes(it) }).to eq(%w[1h30m 1h 45m 0m])
    end
  end
end
