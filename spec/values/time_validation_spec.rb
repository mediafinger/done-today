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
      entries = [ entry("start@09:00"), entry("#break for~30m"), entry("from@10:00 to@11:00 #review"), entry("end@17:30") ]

      expect(messages(entries)).to be_empty
    end
  end

  describe "a daily #break line on a day without a break" do
    it "reports nothing and subtracts no break" do
      entries = [ entry("start@09:00"), entry("#break for~0m"), entry("end@17:00") ]

      expect(messages(entries)).to be_empty
      expect(TimeSummary.new(entries).total_minutes).to eq(8 * 60)
    end
  end

  describe "missing time information" do
    it "is fine for a project that does not require times" do
      expect(described_class.new([ entry("wrote some code"), entry("and some more") ]).issues).to be_empty
    end

    context "when the project requires times" do
      def codes(*entries)
        described_class.new(entries.flatten, times_required: true).issues.map(&:code)
      end

      it "reports a day whose entries carry no markup at all" do
        expect(codes(entry("wrote some code"), entry("and some more"))).to eq(%i[no_times])
      end

      it "stays quiet about it when the markup simply did not parse" do
        expect(codes(entry("start@10:75 kickoff"))).to eq(%i[invalid_time])
      end

      it "reports it per member, not per entry" do
        bert = create(:member, org: day.org, name: "Bert")
        issues = described_class.new([ entry("wrote code"), entry("start@09:00 end@17:00", by: bert) ], times_required: true).issues

        expect(issues.map { [ it.member.name, it.code ] }).to eq([ [ "Anna", :no_times ] ])
      end
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
      expect(messages(entry("start@09:00 #call from@11:00 for~30m end@17:00"))).to be_empty
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

    it "names the markers a too long duration came from" do
      expect(messages(entry("start@01:00 from@01:00 for~30h end@24:00"))).to include("from@01:00 for~30h exceeds 24h")
    end

    it "accepts a day of exactly 24h, from 0:00 to 24:00" do
      expect(messages(entry("start@0:00"), entry("end@24:00"))).to be_empty
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

  describe "tag times beyond the working time" do
    let(:day_of_3h) { [ entry("start@09:00"), entry("end@12:00") ] }

    it "reports tag times that add up to more than the day's total" do
      expect(codes(day_of_3h, entry("#call for~2h"), entry("#review from@10:00 to@11:30"))).to eq(%i[tags_exceed_day])
      expect(codes(day_of_3h, entry("#call for~2h"), entry("#call for~1h30"))).to eq(%i[tags_exceed_day])
    end

    it "points at the day, not at an entry" do
      issue = described_class.new([ day_of_3h, entry("#call for~4h") ].flatten).issues.first

      expect(issue).to have_attributes(code: :tags_exceed_day, entry: nil)
    end

    it "accepts tag times that fill the day exactly" do
      expect(codes(day_of_3h, entry("#call for~2h"), entry("#review for~1h"))).to be_empty
    end

    it "subtracts the breaks from the day first" do
      expect(codes(day_of_3h, entry("#break for~30m"), entry("#call for~2h45m"))).to eq([ :tags_exceed_day ])
    end

    it "counts a todo entry, as the total does" do
      expect(codes(day_of_3h, entry("#call for~4h", status: "todo"))).to eq(%i[tags_exceed_day todo_time])
    end

    it "leaves out durations that count for no tag" do
      found = codes(day_of_3h, entry("#a #b for~4h"), entry("for~4h"), entry("#break #lunch from@09:00 for~1h"))

      expect(found).not_to include(:tags_exceed_day)
    end

    it "says nothing while the day has no total" do
      expect(codes(entry("start@09:00"), entry("#call for~10h"))).to eq([ :missing_end ])
    end

    it "sums each member's tag times against their own total" do
      bert = create(:member, org: day.org, name: "bert")

      expect(codes(day_of_3h, entry("#call for~2h"), entry("#call for~2h", by: bert))).not_to include(:tags_exceed_day)
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
      expect(messages(entry("start@09:00"), entry("end@17:00"), entry("from@16:00 for~60m #review"))).to be_empty
    end

    it "says nothing about a bare for~, which gives no finishing time" do
      found = messages(entry("start@09:00"), entry("end@17:00"), entry("#break for~600m"))

      expect(found).to eq([ "the breaks add up to 10h, longer than the 8h between 09:00 and 17:00" ])
    end

    it "says nothing while the day has no end@ yet" do
      expect(messages(entry("start@09:00"), entry("from@16:00 for~600m #review")))
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
      expect(described_class.new([ entry("wrote code") ], times_required: true).issues.first.entry).to be_nil
    end
  end
end
