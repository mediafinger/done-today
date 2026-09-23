# Checks a day's entries for time markup that cannot add up: syntax the parser had
# to give up on, a start@ without its end@, a total no day can hold, time that is
# still todo.
#
# The parser already reports what it found wrong inside a single log (EntryLog#issues);
# this adds what only becomes visible with the whole day in view. Every member of the
# day is checked on their own -- two people sharing a day have two working times.
#
#   TimeValidation.new(day.entries).issues.map(&:message) # => ["end@17:00 has no start@"]
#
class TimeValidation
  # `entry` is nil for an issue about the day as a whole rather than about one log.
  Issue = Data.define(:code, :message, :member, :entry)

  DAY_MINUTES = 24 * 60

  # markup that was meant to be a time and did not parse -- the reason a day can end
  #   up with no readable time at all
  UNREADABLE = %i[invalid_time invalid_duration].freeze

  def initialize(entries)
    @entries = entries.to_a
  end

  def issues
    @issues ||= by_member.flat_map { |member, member_entries| member_issues(member, member_entries) }
  end

  private

  attr_reader :entries

  def by_member
    entries.group_by(&:member).sort_by { |member, _entries| member.name.downcase }
  end

  def member_issues(member, member_entries)
    parser_issues(member, member_entries) +
      entry_issues(member, member_entries) +
      day_issues(member, member_entries)
  end

  # What EntryLog already found inside a single log: a time or a for~ it could not
  #   read, a repeated marker, a to@ before its from@, a from@ that is still open.
  #   Including the infos, as the only one is that open from@.
  #
  def parser_issues(member, member_entries)
    member_entries.flat_map do |entry|
      entry.parsed.issues.map { |issue| Issue.new(code: issue.code, message: issue.message, member:, entry:) }
    end
  end

  # Per entry: a to@ on its own, and a duration longer than a whole day.
  #
  def entry_issues(member, member_entries)
    member_entries.flat_map do |entry|
      log = entry.parsed
      found = []

      found << Issue.new(code: :missing_from, message: "#{marker(entry, :to)} has no from@", member:, entry:) if log.to_minutes && log.from_minutes.nil?
      found << Issue.new(code: :over_a_day, message: "#{duration_markers(entry)} exceeds 24h", member:, entry:) if log.duration_minutes.to_i > DAY_MINUTES

      found
    end
  end

  # Per member and day: the start@ / end@ pair, the total, and time still marked todo.
  #
  def day_issues(member, member_entries)
    timed = member_entries.select { |entry| timed?(entry) }

    if timed.empty?
      # markup that did not parse is already reported; saying "no time information"
      #   on top of it would only name the same mistake twice
      return [] if member_entries.any? { |entry| entry.parsed.issues.any? { |issue| UNREADABLE.include?(issue.code) } }

      return [ Issue.new(code: :no_times, message: "no time information given", member:, entry: nil) ]
    end

    boundary_issues(member, timed) + total_issues(member, member_entries) +
      past_end_issues(member, member_entries) + todo_issues(member, timed)
  end

  def boundary_issues(member, timed)
    starts = timed.select { |entry| entry.parsed.day_start_minutes }
    ends = timed.select { |entry| entry.parsed.day_end_minutes }

    if ends.empty?
      return [] if starts.empty?

      return [ issue(:missing_end, "#{marker(starts.first, :start)} has no end@", member, starts.first) ]
    end

    return [ issue(:missing_start, "#{marker(ends.first, :end)} has no start@", member, ends.first) ] if starts.empty?
    return [] if ends.first.parsed.day_end_minutes > starts.first.parsed.day_start_minutes

    [ issue(:end_before_start, "#{marker(ends.first, :end)} is not after #{marker(starts.first, :start)}", member, ends.first) ]
  end

  def total_issues(member, member_entries)
    summary = TimeSummary.new(member_entries)
    net = summary.net_minutes

    return [] if net.nil?

    # a day of no working time at all is thin but possible; less than none is not
    if net.negative?
      return [ issue(:negative_total, "the breaks add up to #{TimeSummary.format_minutes(summary.break_minutes)}, " \
                                      "longer than the #{TimeSummary.format_minutes(summary.end_minutes - summary.start_minutes)} " \
                                      "between #{TimeSummary.format_clock(summary.start_minutes)} and " \
                                      "#{TimeSummary.format_clock(summary.end_minutes)}", member, nil) ]
    end

    return [] if net <= DAY_MINUTES

    [ issue(:over_a_day, "the day adds up to #{TimeSummary.format_minutes(net)}, more than 24h", member, nil) ]
  end

  # An entry that starts at a time and runs for a duration finishes at a time, and
  #   that time has no business being after the day ended. Only from@ gives a
  #   starting point -- a bare for~ says how long something took, not when.
  #
  def past_end_issues(member, member_entries)
    ending = TimeSummary.new(member_entries).end_minutes

    return [] if ending.nil?

    member_entries.filter_map do |entry|
      log = entry.parsed
      next unless log.from_minutes && log.duration_minutes

      finish = log.from_minutes + log.duration_minutes
      next if finish <= ending

      issue(:past_end, "#{duration_markers(entry)} runs until #{TimeSummary.format_clock(finish)}, " \
                       "past end@#{TimeSummary.format_clock(ending)}", member, entry)
    end
  end

  # A total that counts a todo entry is a plan, not a record of the day.
  #
  def todo_issues(member, timed)
    timed.select(&:todo?).map { |entry| issue(:todo_time, "#{markers(entry)} is still marked as todo", member, entry) }
  end

  def issue(code, message, member, entry)
    Issue.new(code:, message:, member:, entry:)
  end

  def timed?(entry)
    entry.parsed.segments.any? { |type, _kind, _minutes, _raw| type == :time }
  end

  # The markup that produced a time, as it was typed: "end@17:00".
  #
  def marker(entry, kind)
    entry.parsed.segments.find { |type, segment_kind, _minutes, _raw| type == :time && segment_kind == kind }&.last || "#{kind}@"
  end

  # The markup a duration came from: the for~, or else the from@ / to@ that span it.
  #
  def duration_markers(entry)
    entry.parsed.segments.filter_map { |type, kind, _minutes, raw| raw if type == :time && %i[for from to].include?(kind) }.join(" ")
  end

  def markers(entry)
    entry.parsed.segments.filter_map { |type, _kind, _minutes, raw| raw if type == :time }.join(" ")
  end
end
