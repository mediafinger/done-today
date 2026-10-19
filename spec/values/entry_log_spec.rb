require "rails_helper"

RSpec.describe EntryLog do
  def parse(text, **) = described_class.new(text, **)

  describe "#segments" do
    it "splits prose, tags and times while keeping the source text of each token" do
      segments = parse("fixed the #PR123 from@11:00").segments

      expect(segments).to eq(
        [
          [ :text, "fixed the " ],
          [ :tag, "PR123", "#PR123" ],
          [ :text, " " ],
          [ :time, :from, 660, "from@11:00" ]
        ]
      )
    end

    it "round-trips: the source text of every segment rejoins to the original string" do
      [
        "fixed the #PR123, then #Review",
        "  start@09:00  end@18:00 ",
        "from@11:00 to@12:30 for~1h30m wrote #code",
        "from@10:75 for~1hh x#b sent to@bob a mail",
        "Übung #Sport for~45m — 30 % besser",
        "#tag", "", "   ", "no markup at all"
      ].each do |text|
        expect(parse(text).segments.map(&:last).join).to eq(text)
      end
    end

    it "keeps the segments frozen so the single source of truth cannot be edited in place" do
      expect(parse("#tag").segments).to be_frozen
    end
  end

  describe "tags" do
    it "downcases and dedupes, in order of first appearance" do
      expect(parse("#Review the #PR123 then #review again").tags).to eq(%w[review pr123])
    end

    it "keeps the original casing in the segment, so the log renders as it was typed" do
      expect(parse("#PR123").segments).to eq([ [ :tag, "PR123", "#PR123" ] ])
    end

    it "accepts letters, digits, underscores, slashes and dashes after the first alphanumeric" do
      expect(parse("#a/b-c_d9").tags).to eq([ "a/b-c_d9" ])
    end

    it "excludes trailing punctuation, which stays text" do
      expect(parse("#PR123, done").segments).to eq([ [ :tag, "PR123", "#PR123" ], [ :text, ", done" ] ])
    end

    it "does not start a tag mid-word" do
      expect(parse("x#b").tags).to be_empty
      expect(parse("x#b").segments).to eq([ [ :text, "x#b" ] ])
    end

    it "needs an alphanumeric first character" do
      expect(parse("#-nope # ").tags).to be_empty
    end
  end

  describe "day markers" do
    it "reads start@ and end@ as minutes since midnight" do
      log = parse("start@09:00 end@18:30")

      expect(log.day_start_minutes).to eq(540)
      expect(log.day_end_minutes).to eq(1110)
    end

    it "accepts 0:00 as the start and 24:00 as the end of the day" do
      expect(parse("start@0:00").day_start_minutes).to eq(0)
      expect(parse("end@24:00").day_end_minutes).to eq(1440)
    end

    it "accepts a single-digit hour" do
      expect(parse("start@9:05").day_start_minutes).to eq(545)
    end

    it "is case insensitive" do
      expect(parse("START@09:00").day_start_minutes).to eq(540)
    end

    it "accepts a full stop instead of the colon" do
      expect(parse("start@9.00").day_start_minutes).to eq(540)
      expect(parse("end@17.30").day_end_minutes).to eq(1050)
      expect(parse("from@09.15").segments).to eq([ [ :time, :from, 555, "from@09.15" ] ])
    end

    it "accepts three or four digits without a separator, the last two being the minutes" do
      expect(parse("start@900").day_start_minutes).to eq(540)
      expect(parse("start@0900").day_start_minutes).to eq(540)
      expect(parse("to@1230").to_minutes).to eq(750)
      expect(parse("end@2400").day_end_minutes).to eq(1440)
    end

    it "leaves a full stop that ends the sentence as prose" do
      expect(parse("Done end@17.30.").segments).to eq(
        [ [ :text, "Done " ], [ :time, :end, 1050, "end@17.30" ], [ :text, "." ] ]
      )
      expect(parse("Done end@1730.").day_end_minutes).to eq(1050)
    end
  end

  describe "ranges and durations" do
    it "reads from@ and to@ and derives the duration between them" do
      log = parse("from@11:00 to@12:30")

      expect(log.from_minutes).to eq(660)
      expect(log.to_minutes).to eq(750)
      expect(log.duration_minutes).to eq(90)
    end

    it "reads an explicit for~ in minutes, hours, or both" do
      expect(parse("for~90m").duration_minutes).to eq(90)
      expect(parse("for~1h").duration_minutes).to eq(60)
      expect(parse("for~1h30m").duration_minutes).to eq(90)
    end

    it "reads two digits after whole hours as minutes" do
      expect(parse("for~1h30").duration_minutes).to eq(90)
      expect(parse("for~1h00").duration_minutes).to eq(60)
      expect(parse("for~2h05").duration_minutes).to eq(125)
      expect(parse("for~1h59").duration_minutes).to eq(119)
      expect(parse("#call for~1h30.").segments.last(2)).to eq([ [ :time, :for, 90, "for~1h30" ], [ :text, "." ] ])
    end

    it "reads decimal hours with a point or a comma" do
      expect(parse("#break for~2.5h").duration_minutes).to eq(150)
      expect(parse("#break for~2,5h").duration_minutes).to eq(150)
      expect(parse("for~1.5h30m").duration_minutes).to eq(120)
      expect(parse("for~2.5h").segments).to eq([ [ :time, :for, 150, "for~2.5h" ] ])
    end

    it "rounds decimal hours to whole minutes" do
      expect(parse("for~0.33h").duration_minutes).to eq(20)
      expect(parse("for~0.125h").duration_minutes).to eq(8) # 7.5 rounds up
    end

    it "has no duration when nothing says how long it took" do
      expect(parse("just some prose").duration_minutes).to be_nil
    end
  end

  describe "#timed_tag" do
    it "is the tag on the same line as the duration" do
      expect(parse("#call for~40m").timed_tag).to eq("call")
      expect(parse("from@10:00 to@11:00 #KickOffMeeting").timed_tag).to eq("kickoffmeeting")
      expect(parse("#review #Review for~1h").timed_tag).to eq("review")
    end

    it "is nil without a duration" do
      expect(parse("#call with the client").timed_tag).to be_nil
      expect(parse("#call from@10:00").timed_tag).to be_nil
      expect(parse("#call for~0m").timed_tag).to be_nil
    end

    it "is nil when several tags share the duration" do
      expect(parse("for~1h30 #presenting #kickoff #PR123").timed_tag).to be_nil
    end

    it "is nil on a #break line, as #break marks the day and is no reporting tag" do
      expect(parse("#break for~30m").timed_tag).to be_nil
      expect(parse("#break #lunch for~30m").timed_tag).to be_nil
    end

    it "is nil when the duration has no tag" do
      expect(parse("Call with the client for~30m").timed_tag).to be_nil
    end
  end

  describe "issues" do
    def codes(text, **) = parse(text, **).issues.map(&:code)

    it "reports for~0m as zero_duration and stores no duration" do
      log = parse("for~0m")

      expect(codes("for~0m")).to eq([ :zero_duration ])
      expect(log.duration_minutes).to be_nil
      expect(log.segments).to eq([ [ :time, :for, 0, "for~0m" ] ]) # valid markup, so still a time token
    end

    it "reports minutes over 59 as invalid_time and renders the token as plain text" do
      log = parse("from@10:75")

      expect(codes("from@10:75")).to eq([ :invalid_time ])
      expect(log.from_minutes).to be_nil
      expect(log.segments).to eq([ [ :text, "from@10:75" ] ])
    end

    it "reports a time after 24:00 as invalid_time and renders the token as plain text" do
      log = parse("end@25:30")

      expect(codes("end@25:30")).to eq([ :invalid_time ])
      expect(log.day_end_minutes).to be_nil
      expect(log.segments).to eq([ [ :text, "end@25:30" ] ])
    end

    it "rejects any minute past 24:00" do
      expect(parse("to@24:01").to_minutes).to be_nil
      expect(codes("to@24:01")).to eq([ :invalid_time ])
    end

    it "rejects a three digit minute rather than reading the first two" do
      expect(parse("from@10:005").from_minutes).to be_nil
      expect(codes("from@10:005")).to eq([ :invalid_time ])
    end

    it "rejects digits that do not hold two minute digits, or too many of them" do
      %w[start@9 start@12 start@09001 start@9.5 start@9,00].each do |log|
        expect(parse(log).day_start_minutes).to be_nil, log
        expect(codes(log)).to eq([ :invalid_time ]), log
      end
    end

    it "reports a mistyped time with a full stop whole" do
      expect(parse("start@9.5").segments).to eq([ [ :text, "start@9.5" ] ])
      expect(parse("start@9.5").issues.map(&:message)).to eq([ "start@9.5 is not a valid time, it is kept as text" ])
      expect(parse("start@9x.").issues.map(&:message)).to eq([ "start@9x is not a valid time, it is kept as text" ])
    end

    it "checks the bounds without a separator too" do
      expect(codes("from@1075")).to eq([ :invalid_time ])
      expect(codes("end@3000")).to eq([ :invalid_time ])
    end

    it "reports a mistyped duration but keeps the text" do
      expect(codes("for~1hh")).to eq([ :invalid_duration ])
      expect(codes("for~90")).to eq([ :invalid_duration ]) # no unit
      expect(parse("for~1hh").segments).to eq([ [ :text, "for~1hh" ] ])
      expect(parse("for~1hh").duration_minutes).to be_nil
    end

    it "rejects unit-less minutes that are not two digits from 00 to 59" do
      %w[for~1h5 for~1h60 for~1h75 for~1h300 for~2.5h30 for~1,5h30].each do |log|
        expect(parse(log).duration_minutes).to be_nil, log
        expect(codes(log)).to eq([ :invalid_duration ]), log
        expect(parse(log).segments).to eq([ [ :text, log ] ]), log
      end
    end

    it "rejects more than 59 minutes after hours, with or without the unit" do
      %w[for~1h60m for~1h75m for~2.5h60m].each do |log|
        expect(parse(log).duration_minutes).to be_nil, log
        expect(codes(log)).to eq([ :invalid_duration ]), log
        expect(parse(log).segments).to eq([ [ :text, log ] ]), log
      end
    end

    it "still reads minutes alone beyond 59, and single-digit minutes with their unit" do
      expect(parse("for~135m").duration_minutes).to eq(135)
      expect(parse("for~2h15m").duration_minutes).to eq(135)
      expect(parse("for~1h5m").duration_minutes).to eq(65)
    end

    it "reports a mistyped decimal duration whole, but leaves a trailing full stop as prose" do
      expect(codes("for~1.5m")).to eq([ :invalid_duration ]) # minutes take no decimals
      expect(parse("for~2.5hh").issues.map(&:message)).to eq([ "for~2.5hh is not a valid duration, it is kept as text" ])
      expect(parse("for~2x.").issues.map(&:message)).to eq([ "for~2x is not a valid duration, it is kept as text" ])
    end

    it "leaves prose that only looks like markup alone" do
      expect(codes("sent to@bob a mail")).to be_empty
      expect(parse("sent to@bob a mail").segments).to eq([ [ :text, "sent to@bob a mail" ] ])
    end

    it "reports from@ without to@ or for~ as an open range, as info while the day runs" do
      log = parse("from@11:00 still going")

      expect(log.issues.map { [ _1.code, _1.severity ] }).to eq([ [ :open_range, :info ] ])
      expect(log.from_minutes).to eq(660)
    end

    it "raises the open range to a warning once the day is in the past" do
      log = parse("from@11:00 still going", on_past_day: true)

      expect(log.issues.map { [ _1.code, _1.severity ] }).to eq([ [ :open_range, :warning ] ])
    end

    it "does not report an open range when for~ closes it" do
      expect(codes("#call from@11:00 for~30m")).to be_empty
    end

    it "reports a for~ that disagrees with the from@/to@ span, and lets the range win" do
      log = parse("#call from@11:00 to@12:00 for~30m")

      expect(log.issues.map(&:code)).to eq([ :conflicting_duration ])
      expect(log.duration_minutes).to eq(60)
    end

    it "stays quiet when for~ and the range agree" do
      expect(codes("#call from@11:00 to@12:00 for~1h")).to be_empty
    end

    it "reports to@ earlier than from@ as a negative range and stores no duration" do
      log = parse("from@12:00 to@11:00")

      expect(log.issues.map(&:code)).to eq([ :negative_range ])
      expect(log.duration_minutes).to be_nil
    end

    it "reports an empty range as a zero duration" do
      log = parse("from@12:00 to@12:00")

      expect(log.issues.map(&:code)).to eq([ :zero_duration ])
      expect(log.duration_minutes).to be_nil
    end

    it "keeps the first of a repeated marker and reports the repeat" do
      log = parse("start@09:00 start@10:00")

      expect(log.issues.map(&:code)).to eq([ :duplicate_marker ])
      expect(log.day_start_minutes).to eq(540)
    end

    it "warns when several tags share a duration, which then counts for none of them" do
      log = parse("for~1h30 #presenting #kickoff #PR123")

      expect(log.issues.map(&:code)).to eq([ :ambiguous_tag_time ])
      expect(log.issues.first.severity).to eq(:warning)
      expect(log.issues.first.message).to eq("1h30m has several tags (#presenting #kickoff #pr123), it is counted for none of them")
    end

    it "warns when a #break line carries other tags, which the break does not count for" do
      log = parse("#break #lunch for~30m")

      expect(log.issues.map(&:code)).to eq([ :break_with_tag ])
      expect(log.issues.first.severity).to eq(:warning)
      expect(log.issues.first.message).to eq("the 30m #break is not counted for #lunch")
      expect(codes("#break #lunch #food from@12:00 to@13:00")).to eq([ :break_with_tag ])
    end

    it "hints at a forgotten tag when a duration has none" do
      log = parse("Call with the client from@11:00 to@12:30")

      expect(log.issues.map(&:code)).to eq([ :untagged_duration ])
      expect(log.issues.first.severity).to eq(:info)
      expect(log.issues.first.message).to eq("1h30m has no #tag, is one missing?")
    end

    it "says nothing about tags without a duration, or for a single tag or a plain #break" do
      expect(codes("#a #b notes")).to be_empty
      expect(codes("#break #lunch from@12:00")).to eq([ :open_range ])
      expect(codes("#call for~40m")).to be_empty
      expect(codes("#break for~30m")).to be_empty
      expect(codes("start@09:00 end@17:00")).to be_empty
    end

    it "carries a human readable message on every issue" do
      expect(parse("from@10:75").issues.map(&:message)).to all(be_present)
    end
  end

  describe "#marker_only?" do
    it "is true for markup with no prose around it" do
      expect(parse("start@09:00")).to be_marker_only
      expect(parse("#break from@12:00 to@12:30")).to be_marker_only
    end

    it "is false as soon as there is prose" do
      expect(parse("start@09:00 at the desk")).not_to be_marker_only
      expect(parse("just prose")).not_to be_marker_only
    end

    it "is false for an empty log" do
      expect(parse("")).not_to be_marker_only
    end
  end

  describe "an empty or nil log" do
    it "parses to nothing at all rather than blowing up" do
      [ nil, "", "   " ].each do |text|
        log = parse(text)

        expect(log.tags).to be_empty
        expect(log.issues).to be_empty
        expect(log.duration_minutes).to be_nil
      end
    end
  end
end
