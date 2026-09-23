require "csv"

# The CSV of one month of a project: one line per member who added entries, with
# the hours they logged and the tags they used most.
#
#   export = MonthExport.new(project:, month: Date.new(2026, 9, 1))
#   export.filename # => "org-1_2026-v1_2026_09_done.csv"
#
class MonthExport
  HEADERS = %w[org project member hours tags].freeze

  # `#break` is not work, and TimeSummary has already subtracted it from the hours,
  #   so listing it among the topics worked on would be misleading.
  EXCLUDED_TAGS = %w[break].freeze

  TAG_LIMIT = 20

  attr_reader :project, :month

  # `month` is any date within the month, kept as its first day.
  def initialize(project:, month:)
    @project = project
    @month = month.beginning_of_month
  end

  def to_csv
    CSV.generate do |csv|
      csv << HEADERS

      rows.each do |row|
        csv << [ project.org.name, project.name, row.member.name, hours(row), tags(row) ]
      end
    end
  end

  # The state of the month is part of the name, so an export taken halfway through
  #   a month cannot be mistaken for the finished one.
  #
  def filename
    [ slug(project.org.name), slug(project.name), month.strftime("%Y_%m"), status ].join("_") + ".csv"
  end

  def status
    return "todo" if month > Time.zone.today
    return "done" if month.end_of_month < Time.zone.today

    "doing"
  end

  private

  # PeriodSummary sorts its rows by member name, which is the order the CSV wants.
  def rows
    @rows ||= PeriodSummary.months(entries).first&.rows || []
  end

  def entries
    project.entries.includes(:member, :day).where(days: { date: month..month.end_of_month }).references(:days)
  end

  def hours(row)
    (row.total_minutes.to_i / 60.0).round(2)
  end

  def tags(row)
    row.tag_counts
      .except(*EXCLUDED_TAGS)
      .keys
      .first(TAG_LIMIT)
      .map { |tag| "##{tag}" }
      .join(" ")
  end

  # Names travel into a filename, where spaces and slashes have no business.
  def slug(name)
    name.parameterize
  end
end
