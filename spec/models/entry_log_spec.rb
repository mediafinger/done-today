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

    it "accepts hours up to 29, so end@25:30 unambiguously means 01:30 the next day" do
      expect(parse("end@25:30").day_end_minutes).to eq(1530)
    end

    it "accepts a single-digit hour" do
      expect(parse("start@9:05").day_start_minutes).to eq(545)
    end

    it "is case insensitive" do
      expect(parse("START@09:00").day_start_minutes).to eq(540)
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

    it "has no duration when nothing says how long it took" do
      expect(parse("just some prose").duration_minutes).to be_nil
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

    it "reports hours over 29 as invalid_time and renders the token as plain text" do
      log = parse("end@30:00")

      expect(codes("end@30:00")).to eq([ :invalid_time ])
      expect(log.day_end_minutes).to be_nil
      expect(log.segments).to eq([ [ :text, "end@30:00" ] ])
    end

    it "rejects a three digit minute rather than reading the first two" do
      expect(parse("from@10:005").from_minutes).to be_nil
      expect(codes("from@10:005")).to eq([ :invalid_time ])
    end

    it "reports a mistyped duration but keeps the text" do
      expect(codes("for~1hh")).to eq([ :invalid_duration ])
      expect(codes("for~90")).to eq([ :invalid_duration ]) # no unit
      expect(parse("for~1hh").segments).to eq([ [ :text, "for~1hh" ] ])
      expect(parse("for~1hh").duration_minutes).to be_nil
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
      expect(codes("from@11:00 for~30m")).to be_empty
    end

    it "reports a for~ that disagrees with the from@/to@ span, and lets the range win" do
      log = parse("from@11:00 to@12:00 for~30m")

      expect(log.issues.map(&:code)).to eq([ :conflicting_duration ])
      expect(log.duration_minutes).to eq(60)
    end

    it "stays quiet when for~ and the range agree" do
      expect(codes("from@11:00 to@12:00 for~1h")).to be_empty
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
