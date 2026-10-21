module Mcp
  class GetDayTool < BaseTool
    tool_name "get_day"
    description "Your own entries of one day in a project, the day's start, end, breaks and working time, " \
      "and the time issues the day page would show. #{Schema::UNTRUSTED}"
    input_schema(
      properties: Schema::PROJECT.merge(date: { type: "string", description: "The day, e.g. 2026-03-31" }),
      required: %w[org project date]
    )
    annotations(**Schema::READ_ONLY)

    def run(org:, project:, date:)
      project = find_project(org, project)
      entries = own_entries(project).where(days: { date: date(date, "date") }).includes(:member, day: :project)
        .order(:created_at).to_a
      summary = TimeSummary.new(entries)

      {
        date:, entries: entries.map { entry_data(it) },
        day_start: clock(summary.start_minutes), day_end: clock(summary.end_minutes),
        break_minutes: summary.break_minutes, total_minutes: summary.total_minutes,
        issues: TimeValidation.new(entries, times_required: project.times_required?).issues.map { issue_data(it) }
      }
    end
  end
end
