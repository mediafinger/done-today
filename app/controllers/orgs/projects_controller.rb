module Orgs
  class ProjectsController < AppOrgBaseController
    VIEWS = %w[days weeks months].freeze

    def show
      # TODO: only display:
      #  * projects the member is participant of
      #  * all projects of org, if the member role is owner

      @project = current_org.projects.find_by!(slug: params[:slug])
      @entries_count = @project.entries.size
      @view = view

      # only an owner of both the org and the project may export everybody's entries
      @exportable = current_member.exportable_projects(relation: @project).exists?

      if @view == "days"
        @with_date = true
        @with_project = false
        @with_member = true

        # ONE project, many days
        @days =
          @project.days
            .includes(entries: :member)
            .order("days.date desc", "entries.status desc", "entries.member_id asc", "entries.created_at asc")
      else
        # the week and month views sum up each member's time and tags instead of listing entries
        @periods = PeriodSummary.public_send(@view, @project.entries.includes(:member, :day))
      end

      # ALL the projects, many days
      #
      # TODO: move this code to the Entries controller
      #
      # TODO: add filters for project, day, member, status
      #
      # TODO: allow to configure sorting order: date, project, member (should change column order)
      #
      # TODO: add pagination
      #
      # @days = current_org.days.includes(:project, entries: :member)
      #   .order("days.date desc", "days.project_id asc", "entries.status desc", "entries.member_id asc", "entries.created_at asc")
    end

    def index
      @projects = current_org.projects.order(:name) # require_member guarantees the org
    end

    # One month of the project as a CSV: a line per member, with their hours and
    #   the tags they used most. Scoped to the projects the member may export, so
    #   an unauthorized slug is a 404 rather than a download.
    #
    def export_csv
      project = current_member.exportable_projects.find_by!(slug: params[:slug])

      # an export is named after its month, so a month that cannot be read has to be
      #   corrected rather than guessed
      if month.nil?
        return redirect_to project_path(project.slug, view: "months"),
          alert: t("controllers.unknown_month", month: params[:month].presence || "nothing")
      end

      export = MonthExport.new(project:, month:)

      send_data export.to_csv, filename: export.filename, type: "text/csv"
    end

    # Checks the time markup of every day that has entries, so the days that cannot
    #   add up can be corrected before anyone reads a total off them.
    #
    def validate_times
      @project = current_org.projects.find_by!(slug: params[:slug])

      @days_with_issues =
        @project.days
          .includes(entries: :member)
          .order(date: :desc)
          .filter_map do |day|
            issues = TimeValidation.new(day.entries).issues
            [ day, issues ] if issues.any?
          end
    end

    private

    # an unknown view falls back to the days, rather than raising
    def view
      params[:view].presence_in(VIEWS) || "days"
    end

    # `?month=2026-09`, or nil when it is missing or unreadable
    def month
      return @month if defined?(@month)

      @month =
        begin
          Date.strptime(params[:month].to_s, "%Y-%m")
        rescue Date::Error
          nil
        end
    end
  end
end
