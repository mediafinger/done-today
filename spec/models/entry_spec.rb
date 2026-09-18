require "rails_helper"

RSpec.describe Entry do
  describe "factory" do
    it "creates a persisted entry wired to an org, day and member" do
      entry = create(:entry)

      expect(entry).to be_persisted
      expect(entry.org).to eq(entry.day.org)
      expect(entry.project).to eq(entry.day.project)
    end
  end

  describe "#set_org" do
    it "copies the org from the day when none is given" do
      day = create(:day)

      expect(build(:entry, day:, org: nil).tap(&:validate).org).to eq(day.org)
    end
  end

  describe "parsing the log" do
    it "fills the time-tracking columns from the markup on save" do
      entry = create(:entry, log: "#PR123 review from@11:00 to@12:30 start@09:00 end@18:00")

      expect(entry.reload).to have_attributes(
        tags: [ "pr123" ],
        day_start_minutes: 540,
        day_end_minutes: 1080,
        from_minutes: 660,
        to_minutes: 750,
        duration_minutes: 90
      )
    end

    it "leaves the columns empty when the log has no markup" do
      entry = create(:entry, log: "just wrote some code")

      expect(entry.tags).to eq([])
      expect(entry.duration_minutes).to be_nil
    end

    it "re-parses when the log changes, and drops values the new text no longer carries" do
      entry = create(:entry, log: "#review for~1h")

      entry.update!(log: "#deploy for~30m")

      expect(entry.reload).to have_attributes(tags: [ "deploy" ], duration_minutes: 30)
    end

    it "re-parses before validation, so #parsed never lags behind the text" do
      entry = build(:entry, log: "#review")

      entry.log = "#deploy"

      expect(entry.parsed.tags).to eq([ "deploy" ])
    end

    it "saves the log verbatim even when the markup does not parse" do
      entry = build(:entry, day: create(:day), log: "fixed it for~1hh and from@10:75")

      expect(entry.save).to be(true)
      expect(entry.reload.log).to eq("fixed it for~1hh and from@10:75")
      expect(entry.duration_minutes).to be_nil
      expect(entry.parsed.issues.map(&:code)).to eq(%i[invalid_duration invalid_time])
    end

    it "does not need a day to parse, so a half-built entry still validates its own fields" do
      entry = described_class.new(log: "#review from@11:00", org: build(:org)) # no day yet

      entry.validate

      expect(entry.errors[:log]).to be_empty
      expect(entry.tags).to eq([ "review" ])
    end

    it "warns about an unclosed range only once the day is over" do
      today = build(:entry, log: "from@11:00", day: build(:day, date: Time.zone.today))
      yesterday = build(:entry, log: "from@11:00", day: build(:day, date: Time.zone.yesterday))

      expect(today.parsed.issues.map(&:severity)).to eq([ :info ])
      expect(yesterday.parsed.issues.map(&:severity)).to eq([ :warning ])
    end
  end

  describe "status predicates" do
    it "reports the matching status and only that one" do
      expect(build(:entry, :todo)).to be_todo
      expect(build(:entry, :done)).to be_done
      expect(build(:entry, :todo)).not_to be_done
    end
  end
end
