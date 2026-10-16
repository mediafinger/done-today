require "csv"

# The CSV of one member's days of a project within a month: one line per day they
# added entries on, with the hours they logged and the tags they used most.
#
#   export = DaysExport.new(project:, member:, month: Date.new(2026, 9, 1))
#   export.filename # => "org-1_2026-v1_andy_2026-09-01_2026-09-30.csv"
#
class DaysExport
  include CsvExport

  HEADERS = %w[org project member date hours tags].freeze

  attr_reader :project, :member, :month

  # `month` is any date within the month, kept as its first day.
  def initialize(project:, member:, month:)
    @project = project
    @member = member
    @month = month.beginning_of_month
  end

  def to_csv
    CSV.generate do |csv|
      csv << HEADERS

      rows.each do |date, row|
        csv << [ project.org.name, project.name, member.name, date.iso8601, hours(row), tags(row) ]
      end
    end
  end

  # Named after the first and last day in the CSV. A month without entries has no
  #   such days, so it falls back to the month's own first and last day.
  #
  def filename
    first, last = rows.any? ? [ rows.first.first, rows.last.first ] : [ month, month.end_of_month ]

    [ slug(project.org.name), slug(project.name), slug(member.name), first.iso8601, last.iso8601 ].join("_") + ".csv"
  end

  private

  # [date, PeriodSummary::Row] per day, oldest first. A day is a period of its own
  #   here, holding the entries of one member only, so it has exactly one row.
  #
  def rows
    @rows ||=
      entries
        .group_by { |entry| entry.day.date }
        .sort_by { |date, _entries| date }
        .map { |date, day_entries| [ date, PeriodSummary.new(date, day_entries).rows.first ] }
  end

  def entries
    project.entries.includes(:member, :day)
      .where(member:, days: { date: month..month.end_of_month }).references(:days)
  end
end
