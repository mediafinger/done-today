# The markup examples the help page and the cheat sheet next to the entry field show.
#   spec/values/syntax_guide_spec.rb parses every one of them, so the help cannot
#   drift from what EntryLog accepts.
#
# `parsed` maps EntryLog readers to what they return for `log`; `issues` lists the
#   issue codes, and an example without that key must parse without any.
#
class SyntaxGuide
  Example = Data.define(:markup, :log, :meaning, :parsed)

  EXAMPLES = [
    Example.new(
      markup: "#tag", log: "Reviewed #PR123 with #design",
      meaning: "Tags the entry. A tag starts with a letter or digit and may contain - _ /. " \
               "Case does not matter, and every tag links to all entries carrying it.",
      parsed: { tags: %w[pr123 design] }
    ),
    Example.new(
      markup: "start@", log: "start@09:00",
      meaning: "Your working day starts at 09:00.",
      parsed: { day_start_minutes: 9 * 60 }
    ),
    Example.new(
      markup: "end@", log: "end@17:30",
      meaning: "Your working day ends at 17:30.",
      parsed: { day_end_minutes: (17 * 60) + 30 }
    ),
    Example.new(
      markup: "end@", log: "end@25:30",
      meaning: "Past midnight the hours keep counting, up to 29: this is 01:30 the next morning.",
      parsed: { day_end_minutes: (25 * 60) + 30 }
    ),
    Example.new(
      markup: "from@ to@", log: "Call with the client from@11:00 to@12:30",
      meaning: "A time range. It lasts 1h30m.",
      parsed: { from_minutes: 11 * 60, to_minutes: (12 * 60) + 30, duration_minutes: 90 }
    ),
    Example.new(
      markup: "for~", log: "Planning for~1h30m",
      meaning: "A duration without clock times.",
      parsed: { duration_minutes: 90 }
    ),
    Example.new(
      markup: "for~", log: "Code review for~45m",
      meaning: "Minutes only.",
      parsed: { duration_minutes: 45 }
    ),
    Example.new(
      markup: "for~", log: "Workshop for~2.5h",
      meaning: "Decimal hours: 2h30m.",
      parsed: { duration_minutes: 150 }
    ),
    Example.new(
      markup: "#break", log: "#break for~30m",
      meaning: "A break. Its duration is subtracted from the time between start@ and end@.",
      parsed: { tags: %w[break], duration_minutes: 30 }
    ),
    Example.new(
      markup: "#break", log: "#break from@12:30 to@13:00",
      meaning: "The same break, as a time range.",
      parsed: { tags: %w[break], duration_minutes: 30 }
    )
  ].freeze

  # What looks like markup but stays plain text.
  NOT_MARKUP = [
    Example.new(
      markup: nil, log: "Mailed team#design",
      meaning: "Markup only counts at the start of the log or after a space, so this is no tag.",
      parsed: { tags: [] }
    ),
    Example.new(
      markup: nil, log: "Planning for~90",
      meaning: "A duration needs its unit, h or m. A typo stays in the text and is listed as an issue above your entries.",
      parsed: { duration_minutes: nil, issues: %i[invalid_duration] }
    ),
    Example.new(
      markup: nil, log: "start@9.00",
      meaning: "Clock times need a colon: start@9:00 or start@09:00.",
      parsed: { day_start_minutes: nil, issues: %i[invalid_time] }
    )
  ].freeze

  # One day's logs and the working time they add up to: end@ - start@ - breaks.
  DAY = [ "start@09:00", "#break for~30m", "end@17:30" ].freeze
  DAY_TOTAL = "8h"
end
