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

  describe "#format_minutes" do
    it "writes a duration the way for~ reads it" do
      expect([ 90, 60, 45, 0 ].map { helper.format_minutes(it) }).to eq(%w[1h30m 1h 45m 0m])
    end
  end
end
