module Mcp
  # Every tool of the MCP server runs as an instance: `run` returns JSON-able data, with
  #   ActionPolicy on behalf of Current.connection. Like verify_authorized, a tool that
  #   neither authorizes nor scopes raises. Refusals and unknown records are tool errors.
  #
  class BaseTool < MCP::Tool
    include ActionPolicy::Behaviour

    # a refusal the client should read, e.g. a locked past day
    class Error < StandardError; end
    class NotAuthorized < StandardError; end

    authorize :connection, through: :current_connection

    def self.call(server_context:, **arguments)
      Time.use_zone(Current.user.time_zone || Time.zone_default) do
        MCP::Tool::Response.new([ { type: "text", text: JSON.generate(new(**arguments).perform) } ])
      end
    rescue Error, ActionPolicy::Unauthorized, ActiveRecord::RecordNotFound => e
      MCP::Tool::Response.new([ { type: "text", text: error_message(e) } ], error: true)
    end

    def self.error_message(error)
      case error
      when ActionPolicy::Unauthorized then "This token may not do that."
      when ActiveRecord::RecordNotFound then "Not found among the projects and entries this token reaches."
      else error.message
      end
    end

    def initialize(**arguments)
      @arguments = arguments
    end

    def perform
      run(**@arguments).tap { raise NotAuthorized, "#{self.class.name} neither authorized nor scoped" unless @authorized }
    end

    def authorize!(...)
      super.tap { @authorized = true }
    end

    def authorized_scope(...)
      super.tap { @authorized = true }
    end

    private

    def current_connection
      Current.connection
    end

    # A project the connection reads, by its slugs. Sets Current.org and Current.member
    #   for what the tool writes, like OrgScope does for the pages.
    #
    def find_project(org, project)
      found = authorized_scope(Project.all, with: ProjectPolicy).joins(:org).find_by!(orgs: { slug: org }, slug: project)

      Current.org = found.org
      Current.member = Current.user.memberships.active.find_by!(org: found.org)
      found
    end

    def own_entries(project)
      authorized_scope(Entry.all, with: EntryPolicy).joins(:day).where(days: { project_id: project.id })
    end

    def date(value, name)
      Date.iso8601(value.to_s)
    rescue Date::Error
      raise Error, "#{name} must be a date like 2026-03-31"
    end

    # a week, month or year as the reports take them (ReportPeriod), the current month by default
    def report_period(arguments)
      ReportPeriod.from_params(arguments, today: Time.zone.today) or
        raise Error, "give one of week (2026-W12), month (2026-03) or year (2026)"
    end

    def clock(minutes)
      TimeSummary.format_clock(minutes) if minutes
    end

    def entry_data(entry)
      {
        id: entry.id, date: entry.day.date.iso8601, status: entry.status, log: entry.log, tags: entry.tags,
        timed_tag: entry.timed_tag, day_start: clock(entry.day_start_minutes), day_end: clock(entry.day_end_minutes),
        from: clock(entry.from_minutes), to: clock(entry.to_minutes), duration_minutes: entry.duration_minutes,
        updated_at: entry.updated_at.iso8601(6)
      }.compact
    end

    def issue_data(issue)
      { date: issue.entry&.day&.date&.iso8601, code: issue.code, message: issue.message, entry_id: issue.entry&.id }.compact
    end
  end
end
