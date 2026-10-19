require "csv"

# The CSV of the tag times report (TagTimes) of a period: one line per tag, member and project.
#   No total lines: a tag's total is the sum of its lines, so the sheet sums without counting twice.
#
#   export = TagTimesExport.new(entries:, org:, period:, project:)
#   export.filename # => "acme_website_tag-times_2026-10.csv"
#
class TagTimesExport
  include CsvExport

  HEADERS = %w[org project period tag member hours minutes].freeze

  # `entries` are already narrowed down to the period, project and member,
  #   `project` and `member` only name the file
  def initialize(entries:, org:, period:, project: nil, member: nil)
    @entries = entries
    @org = org
    @period = period
    @project = project
    @member = member
  end

  def to_csv
    CSV.generate do |csv|
      csv << HEADERS

      rows.each do |tag, member, project, minutes|
        csv << [ org.name, project.name, period.label, "##{tag}", member.name, hours_of(minutes), minutes ]
      end
    end
  end

  def filename
    [ slug(org.name), project && slug(project.name), member && slug(member.name), "tag-times", period.label ].compact.join("_") + ".csv"
  end

  private

  attr_reader :entries, :org, :period, :project, :member

  # [tag, member, project, minutes], by tag, member name and project name
  def rows
    @rows ||= sums.map { |(project_id, tag, member_id), minutes| [ tag, members.fetch(member_id), projects.fetch(project_id), minutes ] }
      .sort_by { |tag, member, project, _minutes| [ tag, member.name.downcase, project.name.downcase ] }
  end

  # { [project_id, tag, member_id] => minutes }
  def sums
    @sums ||= entries.joins(:day).where.not(timed_tag: nil)
      .group(Day.arel_table[:project_id], :timed_tag, :member_id).sum(:duration_minutes)
  end

  # archived ones included, their time was logged
  def members
    @members ||= Member.where(id: sums.keys.map(&:last).uniq).index_by(&:id)
  end

  def projects
    @projects ||= Project.where(id: sums.keys.map(&:first).uniq).index_by(&:id)
  end
end
