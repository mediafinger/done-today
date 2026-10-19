require "rails_helper"

RSpec.describe ReportPeriod do
  let(:today) { Date.new(2026, 10, 14) } # a Wednesday

  def from(params)
    described_class.from_params(params, today:)
  end

  describe ".from_params" do
    it "is the current month without a period" do
      expect(from({})).to have_attributes(kind: :month, range: Date.new(2026, 10, 1)..Date.new(2026, 10, 31))
    end

    it "reads a week, Monday to Sunday" do
      expect(from(week: "2026-W42")).to have_attributes(kind: :week, range: Date.new(2026, 10, 12)..Date.new(2026, 10, 18))
    end

    it "reads a month" do
      expect(from(month: "2026-02")).to have_attributes(kind: :month, range: Date.new(2026, 2, 1)..Date.new(2026, 2, 28))
    end

    it "reads a year" do
      expect(from(year: "2025")).to have_attributes(kind: :year, range: Date.new(2025, 1, 1)..Date.new(2025, 12, 31))
    end

    it "takes the week first when several periods are given" do
      expect(from(year: "2025", month: "2026-02", week: "2026-W42").kind).to eq(:week)
    end

    it "is nil for a period it cannot read" do
      expect([ from(week: "2026-W54"), from(month: "2026-13"), from(year: "26"), from(year: "2026x") ]).to all(be_nil)
    end
  end

  describe ".kind_in" do
    it "names the period the params ask for" do
      expect([ described_class.kind_in({}), described_class.kind_in(year: "x") ]).to eq([ nil, :year ])
    end
  end

  describe "#param and #label" do
    it "write the period the way the URL takes it" do
      periods = [ from(week: "2026-W01"), from(month: "2026-10"), from(year: "2026") ]

      expect(periods.map(&:param)).to eq([ { week: "2026-W01" }, { month: "2026-10" }, { year: "2026" } ])
      expect(periods.map(&:label)).to eq(%w[2026-W01 2026-10 2026])
    end
  end

  describe "#previous and #following" do
    it "are the periods of the same kind next to it" do
      week = from(week: "2026-W01")
      year = from(year: "2026")

      expect([ week.previous.param, week.following.param ]).to eq([ { week: "2025-W52" }, { week: "2026-W02" } ])
      expect([ year.previous.param, year.following.param ]).to eq([ { year: "2025" }, { year: "2027" } ])
    end
  end

  describe "#as" do
    it "switches to the period of another kind around today when today lies in this one" do
      expect(from({}).as(:week, today:).param).to eq(week: "2026-W42")
    end

    it "switches to the period of another kind around its start otherwise" do
      expect(from(month: "2026-03").as(:week, today:).param).to eq(week: "2026-W09")
    end
  end
end
