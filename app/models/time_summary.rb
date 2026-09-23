# Sums up the time markup of a set of entries -- usually one member's entries of
# one day: when the day started and ended, how long the breaks took, and the
# working time that is left.
#
# A PORO over already loaded entries, reading the columns `EntryLog` fills in, so
# the same object serves the day page and the project page without extra queries.
#
#   summary = TimeSummary.new(entries) # start@09:00, #break for~30m, end@17:30
#   summary.total_minutes              # => 480
#
class TimeSummary
  BREAK_TAG = "break"

  attr_reader :entries

  # One summary per member, ordered by name -- a day holds the entries of everyone
  # in the project, and their start and end times must not be mixed up.
  #
  def self.by_member(entries)
    entries
      .group_by(&:member)
      .sort_by { |member, _entries| member.name }
      .map { |member, member_entries| [ member, new(member_entries) ] }
  end

  # Minutes since midnight as a clock time: 570 => "09:30". Hours run past 23 on
  #   purpose (`end@25:30`, see EntryLog::MAX_HOUR), so they are not wrapped.
  #
  def self.format_clock(minutes)
    format("%02d:%02d", *minutes.divmod(60))
  end

  # A duration in the notation `for~` accepts: 90 => "1h30m", 60 => "1h", 45 => "45m".
  #   Lives here rather than in the helper alone, so TimeValidation can word its
  #   messages the same way the pages do.
  #
  def self.format_minutes(minutes)
    hours, rest = minutes.divmod(60)

    return "#{rest}m" if hours.zero?

    rest.zero? ? "#{hours}h" : "#{hours}h#{rest}m"
  end

  # Each member's total per day, for lists that span several days:
  #   { [day_id, member_id] => minutes }, leaving out the days without a total.
  #
  def self.day_totals(entries)
    entries
      .group_by { |entry| [ entry.day_id, entry.member_id ] }
      .transform_values { |day_entries| new(day_entries).total_minutes }
      .compact
  end

  def initialize(entries)
    @entries = entries.to_a
  end

  def start_minutes
    @start_minutes ||= entries.filter_map(&:day_start_minutes).min
  end

  def end_minutes
    @end_minutes ||= entries.filter_map(&:day_end_minutes).max
  end

  def break_minutes
    @break_minutes ||= break_entries.sum(&:duration_minutes)
  end

  # Needs both ends of the day. An end before the start is a typo, not a
  # negative working day, so it yields nil rather than a number.
  #
  def total_minutes
    return nil if net_minutes.nil?

    # breaks longer than the day would make this negative, which is a mistake in the
    #   markup rather than a working time -- TimeValidation reports it, and no page
    #   has any use for a negative total in the meantime
    [ net_minutes, 0 ].max
  end

  # The working time as the markup states it, which is negative when the breaks are
  #   longer than the day between start@ and end@.
  #
  def net_minutes
    return nil unless start_minutes && end_minutes && end_minutes > start_minutes

    end_minutes - start_minutes - break_minutes
  end

  def times?
    timed_entries.any?
  end

  # The status of the lines the time information comes from: "todo" while any of
  # them is still todo, "doing" while any is in progress, nil once all are done.
  #
  def status
    statuses = timed_entries.map(&:status)

    if statuses.include?("todo")
      "todo"
    elsif statuses.include?("doing")
      "doing"
    end
  end

  def tags
    @tags ||= entries.flat_map(&:tags).uniq.sort
  end

  private

  # A break without a duration (an open `from@`) has nothing to subtract yet.
  def break_entries
    @break_entries ||= entries.select { |entry| entry.tags.include?(BREAK_TAG) && entry.duration_minutes }
  end

  def timed_entries
    @timed_entries ||= entries.select do |entry|
      entry.day_start_minutes || entry.day_end_minutes || break_entries.include?(entry)
    end
  end
end
