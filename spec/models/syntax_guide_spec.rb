require "rails_helper"

# The help page and the cheat sheet render these examples verbatim, so parsing each
#   one here keeps the help from promising markup EntryLog does not accept.
#
RSpec.describe SyntaxGuide do
  def parse_as_documented(example)
    log = EntryLog.new(example.log)
    expected = { issues: [] }.merge(example.parsed)

    actual = expected.keys.index_with do |reader|
      reader == :issues ? log.issues.map(&:code) : log.public_send(reader)
    end

    [ actual, expected ]
  end

  (described_class::EXAMPLES + described_class::NOT_MARKUP).each do |example|
    it "parses #{example.log.inspect} the way the help explains it" do
      actual, expected = parse_as_documented(example)

      expect(actual).to eq(expected)
    end
  end

  it "documents every kind of markup the parser knows" do
    markups = described_class::EXAMPLES.map(&:markup).join(" ")

    expect(markups).to include("#tag", "start@", "end@", "from@", "to@", "for~", "#break")
  end

  it "adds the example day up to the working time it states" do
    day = create(:day)
    member = create(:member, org: day.org)
    entries = described_class::DAY.map { create(:entry, day:, member:, log: it) }

    expect(TimeSummary.format_minutes(TimeSummary.new(entries).total_minutes)).to eq(described_class::DAY_TOTAL)
  end
end
