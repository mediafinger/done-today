# Sums up a project's entries per period -- a calendar week or a month -- and
# within it per member: the time they worked and the tags they used.
#
# A PORO over already loaded entries, like TimeSummary, which it builds on: the
# working time of a day needs that day's start@, end@ and breaks, so a period's
# total is the sum of its members' day totals.
#
#   PeriodSummary.weeks(project.entries).first.rows.first.total_minutes # => 2310
#
class PeriodSummary
  Row = Data.define(:member, :total_minutes, :tags)

  # How a week travels in a URL: 2026-W39. strptime turns it back into its Monday.
  WEEK_PARAM = "%G-W%V"

  # `start` is the first day of the period: the Monday of an ISO week, the 1st
  #   of a month. Newest period first, like the day list of the project page.
  attr_reader :start

  def self.weeks(entries)
    group(entries) { |date| date.beginning_of_week(:monday) }
  end

  def self.months(entries)
    group(entries, &:beginning_of_month)
  end

  def self.group(entries, &period_start)
    entries
      .group_by { |entry| period_start.call(entry.day.date) }
      .sort_by { |start, _entries| start }
      .reverse
      .map { |start, period_entries| new(start, period_entries) }
  end

  def initialize(start, entries)
    @start = start
    @entries = entries
  end

  # One row per member who added entries in the period, in alphabetical order.
  #
  def rows
    @rows ||=
      @entries
        .group_by(&:member)
        .sort_by { |member, _entries| member.name.downcase }
        .map do |member, member_entries|
          Row.new(member:, total_minutes: total_minutes(member_entries), tags: member_entries.flat_map(&:tags).uniq.sort)
        end
  end

  private

  # nil rather than 0 when no day of the period has both start@ and end@ --
  #   nothing was logged, which is not the same as zero hours worked.
  def total_minutes(member_entries)
    day_totals = member_entries.group_by(&:day_id).values.filter_map { |day_entries| TimeSummary.new(day_entries).total_minutes }

    day_totals.sum if day_totals.any?
  end
end
