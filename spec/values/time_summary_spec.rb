require "rails_helper"

RSpec.describe TimeSummary do
  let(:day) { create(:day) }
  let(:member) { create(:member, org: day.org) }

  def entry(log, status: "done", by: member)
    create(:entry, day:, member: by, log:, status:)
  end

  describe "a day with start, end and breaks" do
    subject(:summary) do
      described_class.new([
        entry("start@09:00"),
        entry("#break for~30m"),
        entry("#Break from@15:00 to@15:15"),
        entry("reviewed #PR123"),
        entry("end@17:45")
      ])
    end

    it "takes the day's span from start@ and end@" do
      expect(summary).to have_attributes(start_minutes: 540, end_minutes: 1065)
    end

    it "adds up every #break, whether given as for~ or as a range" do
      expect(summary.break_minutes).to eq(45)
    end

    it "subtracts the breaks from the span" do
      expect(summary.total_minutes).to eq(480)
    end

    it "collects the tags of all entries, downcased and deduplicated" do
      expect(summary.tags).to eq(%w[break pr123])
    end
  end

  describe "#total_minutes" do
    it "is nil while the day has no end yet" do
      expect(described_class.new([ entry("start@09:00") ]).total_minutes).to be_nil
    end

    it "is nil without a start" do
      expect(described_class.new([ entry("end@17:00") ]).total_minutes).to be_nil
    end

    it "is nil when the day ends before it starts" do
      expect(described_class.new([ entry("start@17:00"), entry("end@09:00") ]).total_minutes).to be_nil
    end

    it "takes start and end from the same entry" do
      expect(described_class.new([ entry("start@09:00 end@12:00") ]).total_minutes).to eq(180)
    end

    it "ignores a break that has no duration yet" do
      summary = described_class.new([ entry("start@09:00"), entry("#break from@12:00"), entry("end@12:00") ])

      expect(summary.total_minutes).to eq(180)
    end
  end

  describe "#net_minutes" do
    it "goes negative when the breaks are longer than the day" do
      summary = described_class.new([ entry("start@12:00"), entry("end@18:00"), entry("#break from@15:00 for~400m") ])

      expect(summary).to have_attributes(net_minutes: -40, total_minutes: 0)
    end
  end

  describe "#times?" do
    it "is false for entries without start@, end@ or a timed break" do
      expect(described_class.new([ entry("#break"), entry("from@10:00 to@11:00") ])).not_to be_times
    end

    it "is true for a timed break alone" do
      expect(described_class.new([ entry("#break for~15m") ])).to be_times
    end
  end

  describe "#status" do
    it "is todo while any time entry is todo, even when others are doing" do
      summary = described_class.new([ entry("start@09:00", status: "doing"), entry("end@17:00", status: "todo") ])

      expect(summary.status).to eq("todo")
    end

    it "is doing while a time entry is doing and none is todo" do
      summary = described_class.new([ entry("start@09:00", status: "doing"), entry("end@17:00") ])

      expect(summary.status).to eq("doing")
    end

    it "is nil once every time entry is done" do
      expect(described_class.new([ entry("start@09:00"), entry("end@17:00") ]).status).to be_nil
    end

    it "ignores entries that carry no time information" do
      summary = described_class.new([ entry("start@09:00"), entry("still on it", status: "todo") ])

      expect(summary.status).to be_nil
    end
  end

  describe ".day_totals" do
    it "keys each member's total by day and member, leaving out days without one" do
      zoe = create(:member, org: day.org, name: "Zoe")
      next_day = create(:day, project: day.project, date: day.date + 1)
      entry("start@09:00")
      entry("#break for~30m")
      entry("end@12:00")
      entry("start@10:00 end@11:00", by: zoe)
      create(:entry, day: next_day, member:, log: "start@08:00 end@09:15")
      create(:entry, day: next_day, member: zoe, log: "no times here")

      expect(described_class.day_totals(Entry.includes(:member))).to eq(
        [ day.id, member.id ] => 150,
        [ day.id, zoe.id ] => 60,
        [ next_day.id, member.id ] => 75
      )
    end
  end

  describe ".by_member" do
    it "keeps the members' times apart, ordered by name" do
      anna = create(:member, org: day.org, name: "Anna")
      zoe = create(:member, org: day.org, name: "Zoe")

      summaries = described_class.by_member([
        entry("start@10:00", by: zoe), entry("start@08:00", by: anna), entry("end@12:00", by: zoe)
      ])

      expect(summaries.map { |member, summary| [ member.name, summary.start_minutes, summary.total_minutes ] })
        .to eq([ [ "Anna", 480, nil ], [ "Zoe", 600, 120 ] ])
    end
  end
end
