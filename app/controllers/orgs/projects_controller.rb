module Orgs
  class ProjectsController < AppOrgBaseController
    VIEWS = %w[days weeks months].freeze

    # every action but the org's list of projects is below /:org_slug/:project_slug
    before_action :set_current_project, except: :index

    def show
      @project = current_project
      @entries_count = @project.entries.size
      @view = view

      @exportable = policy(@project).export?

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
      @projects = ProjectPolicy.readable(current_member).order(:name)
    end

    # One month of the project as a CSV: a line per member, with their hours and
    #   the tags they used most. Scoped to the projects the member may export, so
    #   an unauthorized slug is a 404 rather than a download.
    #
    def export_csv
      project = exportable_project

      # an export is named after its month, so a month that cannot be read has to be
      #   corrected rather than guessed
      if month.nil?
        return redirect_to project_path(current_org, project, view: "months"),
          alert: t("controllers.unknown_month", month: params[:month].presence || "nothing")
      end

      export = MonthExport.new(project:, month:)

      send_data export.to_csv, filename: export.filename, type: "text/csv"
    end

    # One member's days of a month as a CSV: a line per day, with their hours and
    #   the tags they used most. Same permission as the month export.
    #
    def export_days_csv
      project = exportable_project
      member = project.org.members.find(params[:member_id])

      if month.nil?
        return redirect_to project_path(current_org, project, view: "months"),
          alert: t("controllers.unknown_month", month: params[:month].presence || "nothing")
      end

      export = DaysExport.new(project:, member:, month:)

      send_data export.to_csv, filename: export.filename, type: "text/csv"
    end

    # Checks the time markup of every day that has entries, so the days that cannot
    #   add up can be corrected before anyone reads a total off them.
    #
    def validate_times
      @project = current_project

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

    # a project the member may read but not export is a 404 as well
    def exportable_project
      ProjectPolicy.exportable(current_member).find(current_project.id)
    end

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
