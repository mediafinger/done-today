module Mcp
  class GetTimeIssuesTool < BaseTool
    tool_name "get_time_issues"
    description "The time issues of your own entries in a project for a week, a month or a year, day by day: " \
      "markup that didn't parse, a start@ without end@, tag times beyond the working time, and the like."
    input_schema(properties: Schema::PROJECT.merge(Schema::PERIOD), required: %w[org project])
    annotations(**Schema::READ_ONLY)

    def run(org:, project:, **period)
      period = report_period(period)
      project = find_project(org, project)
      entries = own_entries(project).where(days: { date: period.range }).includes(:member, day: :project)

      entries.group_by(&:day).sort_by { |day, _entries| day.date }.flat_map do |_day, day_entries|
        TimeValidation.new(day_entries, times_required: project.times_required?).issues.map { issue_data(it) }
      end
    end
  end
end
