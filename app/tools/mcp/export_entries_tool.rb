module Mcp
  class ExportEntriesTool < BaseTool
    tool_name "export_entries"
    description "Your own hours of a month in a project as CSV, like the project page's exports: " \
      "a line per day (per: day, the default) or the month's total (per: month), with the tags you used most."
    input_schema(
      properties: Schema::PROJECT.merge(
        month: Schema::PERIOD[:month],
        per: { type: "string", enum: %w[day month], description: "A line per day (default) or one for the month" }
      ),
      required: %w[org project]
    )
    annotations(**Schema::READ_ONLY)

    def run(org:, project:, month: nil, per: "day")
      project = find_project(org, project)
      month = report_period(month ? { month: } : {}).start
      export =
        if per == "month"
          MonthExport.new(project:, month:, member: Current.member)
        else
          DaysExport.new(project:, member: Current.member, month:)
        end

      { filename: export.filename, csv: export.to_csv }
    end
  end
end
