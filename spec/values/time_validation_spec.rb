require "rails_helper"

RSpec.describe TimeValidation do
  let(:day) { create(:day, date: Date.new(2026, 9, 21)) } # a past day, so the parser is strict
  let(:member) { create(:member, org: day.org, name: "Anna") }

  def entry(log, status: "done", by: member)
    create(:entry, day:, member: by, log:, status:)
  end

  def messages(*entries)
    described_class.new(entries.flatten).issues.map(&:message)
  end

  def codes(*entries)
    described_class.new(entries.flatten).issues.map(&:code)
  end

  describe "a day that adds up" do
    it "reports nothing" do
      entries = [ entry("start@09:00"), entry("#break for~30m"), entry("from@10:00 to@11:00 review"), entry("end@17:30") ]

      expect(messages(entries)).to be_empty
    end
  end

  describe "missing time information" do
    it "reports a day whose entries carry no markup at all" do
      expect(messages(entry("wrote some code"), entry("and some more"))).to eq([ "no time information given" ])
    end

    it "stays quiet about it when the markup simply did not parse" do
      expect(messages(entry("start@10:75 kickoff"))).to eq([ "start@10:75 is not a valid time, it is kept as text" ])
    end

    it "reports it per member, not per entry" do
      bert = create(:member, org: day.org, name: "Bert")
      issues = described_class.new([ entry("wrote code"), entry("start@09:00 end@17:00", by: bert) ]).issues

      expect(issues.map { [ it.member.name, it.code ] }).to eq([ [ "Anna", :no_times ] ])
    end
  end

  describe "markup the parser cannot read" do
    it "reports a start@ that is not a time" do
      expect(messages(entry("start@10:75 kickoff"))).to include("start@10:75 is not a valid time, it is kept as text")
    end

    it "reports an end@ that is not a time" do
      expect(codes(entry("start@09:00 end@30:00"))).to include(:invalid_time)
    end

    it "reports a from@ that is not a time" do
      expect(codes(entry("from@1a:00 to@12:00"))).to include(:invalid_time)
    end

    it "reports a to@ that is not a time" do
      expect(codes(entry("from@11:00 to@12:99"))).to include(:invalid_time)
    end

    it "reports a for~ that is not a duration" do
      expect(messages(entry("#break for~1hh"))).to include("for~1hh is not a valid duration, it is kept as text")
    end
  end

  describe "the start@ and end@ of a day" do
    it "reports a start@ without an end@" do
      expect(messages(entry("start@09:00"))).to eq([ "start@09:00 has no end@" ])
    end

    it "reports an end@ without a start@" do
      expect(messages(entry("end@17:00"))).to eq([ "end@17:00 has no start@" ])
    end

    it "reports an end@ before the start@" do
      expect(messages(entry("start@17:00"), entry("end@09:00"))).to eq([ "end@09:00 is not after start@17:00" ])
    end

    it "reports an end@ at the very time of the start@" do
      expect(messages(entry("start@09:00 end@09:00"))).to eq([ "end@09:00 is not after start@09:00" ])
    end

    it "accepts a start@ and end@ that sit in one entry" do
      expect(messages(entry("start@09:00 end@17:00"))).to be_empty
    end
  end

  describe "the from@ and to@ of an entry" do
    it "reports a from@ with neither to@ nor for~" do
      expect(messages(entry("start@09:00 from@11:00 end@17:00"))).to eq([ "from@ has no to@ or for~ yet" ])
    end

    it "accepts a from@ closed by a for~" do
      expect(messages(entry("start@09:00 from@11:00 for~30m end@17:00"))).to be_empty
    end

    it "reports a to@ without a from@" do
      expect(messages(entry("start@09:00 to@12:00 end@17:00"))).to eq([ "to@12:00 has no from@" ])
    end

    it "reports a to@ before the from@" do
      expect(messages(entry("start@09:00 from@12:00 to@11:00 end@17:00"))).to eq([ "to@ is earlier than from@" ])
    end

    it "reports a to@ at the very time of the from@" do
      expect(messages(entry("start@09:00 from@12:00 to@12:00 end@17:00"))).to eq([ "from@ and to@ are the same time" ])
    end
  end

  describe "more than a day" do
    it "reports a single duration longer than 24h" do
      expect(messages(entry("start@09:00 for~40h end@17:00"))).to include("for~40h exceeds 24h")
    end

    it "names the range a too long duration came from" do
      expect(messages(entry("start@01:00 from@01:00 to@26:00 end@26:00"))).to include("from@01:00 to@26:00 exceeds 24h")
    end

    it "reports a day that adds up to more than 24h" do
      expect(messages(entry("start@01:00"), entry("end@26:00"))).to include("the day adds up to 25h, more than 24h")
    end

    it "accepts a day of exactly 24h" do
      expect(messages(entry("start@01:00"), entry("end@25:00"))).to be_empty
    end
  end

  describe "breaks longer than the day" do
    it "reports a day whose breaks swallow more than the whole day" do
      expect(messages(entry("start@12:00"), entry("end@18:00"), entry("#break from@15:00 for~400m")))
        .to include("the breaks add up to 6h40m, longer than the 6h between 12:00 and 18:00")
    end

    it "accepts a day whose breaks take exactly all of it" do
      expect(messages(entry("start@12:00"), entry("end@18:00"), entry("#break from@12:00 for~360m")))
        .to be_empty
    end
  end

  describe "an entry that runs past the end of the day" do
    it "reports a from@ whose duration reaches beyond end@" do
      expect(messages(entry("start@12:00"), entry("end@18:00"), entry("#break from@15:00 for~400m")))
        .to include("from@15:00 for~400m runs until 21:40, past end@18:00")
    end

    it "reports a from@ and to@ range that ends after end@" do
      expect(messages(entry("start@09:00"), entry("end@17:00"), entry("from@16:00 to@18:30 review")))
        .to include("from@16:00 to@18:30 runs until 18:30, past end@17:00")
    end

    it "accepts an entry that finishes exactly at end@" do
      expect(messages(entry("start@09:00"), entry("end@17:00"), entry("from@16:00 for~60m review"))).to be_empty
    end

    it "says nothing about a bare for~, which gives no finishing time" do
      found = messages(entry("start@09:00"), entry("end@17:00"), entry("#break for~600m"))

      expect(found).to eq([ "the breaks add up to 10h, longer than the 8h between 09:00 and 17:00" ])
    end

    it "says nothing while the day has no end@ yet" do
      expect(messages(entry("start@09:00"), entry("from@16:00 for~600m review")))
        .to eq([ "start@09:00 has no end@" ])
    end
  end

  describe "time that is still todo" do
    it "reports a time entry in status todo" do
      expect(messages(entry("start@09:00"), entry("end@17:00", status: "todo")))
        .to eq([ "end@17:00 is still marked as todo" ])
    end

    it "ignores a todo entry that carries no time" do
      expect(messages(entry("start@09:00"), entry("end@17:00"), entry("still to do", status: "todo"))).to be_empty
    end

    it "reports a todo break, as it is subtracted from the total" do
      expect(messages(entry("start@09:00"), entry("#break for~30m", status: "todo"), entry("end@17:00")))
        .to eq([ "for~30m is still marked as todo" ])
    end
  end

  describe "several members" do
    it "checks each member on their own, in alphabetical order" do
      bert = create(:member, org: day.org, name: "bert")
      issues = described_class.new([
        entry("start@09:00", by: bert), entry("end@17:00"), entry("start@10:00", by: bert)
      ]).issues

      expect(issues.map { [ it.member.name, it.message ] }).to eq([
        [ "Anna", "end@17:00 has no start@" ],
        [ "bert", "start@09:00 has no end@" ]
      ])
    end
  end

  describe "#issues" do
    it "points at the entry that carries the markup, and at none for the day itself" do
      open_start = entry("start@09:00")

      issue = described_class.new([ open_start ]).issues.first

      expect(issue).to have_attributes(code: :missing_end, entry: open_start, member:)
      expect(described_class.new([ entry("wrote code") ]).issues.first.entry).to be_nil
    end
  end
end
