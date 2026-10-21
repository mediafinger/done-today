module Mcp
  class GetSummaryTool < BaseTool
    tool_name "get_summary"
    description "Your own working time in a project for a week, a month or a year: the total, " \
      "the total per day, and the time per tag (for~ durations)."
    input_schema(properties: Schema::PROJECT.merge(Schema::PERIOD), required: %w[org project])
    annotations(**Schema::READ_ONLY)

    def run(org:, project:, **period)
      period = report_period(period)
      entries = own_entries(find_project(org, project)).where(days: { date: period.range })
      days = TimeSummary.day_totals(entries.includes(:day).to_a)
      dates = Day.where(id: days.keys.map(&:first)).pluck(:id, :date).to_h

      {
        period: period.label, from: period.start.iso8601, to: period.finish.iso8601,
        total_minutes: days.values.sum,
        days: days.map { |(day_id, _member_id), minutes| { date: dates.fetch(day_id).iso8601, total_minutes: minutes } }.sort_by { it[:date] },
        tag_minutes: TagTimes.new(entries).rows.to_h { [ it.tag, it.minutes ] }
      }
    end
  end
end
