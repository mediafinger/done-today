module Orgs
  # A project's pages, and its management: org owners create projects, org and
  #   project owners rename, archive and unarchive them. Projects are never deleted.
  #
  class ProjectsController < AppOrgBaseController
    VIEWS = %w[days weeks months].freeze

    # every action but the org's list of projects and creating one is below /:org_slug/:project_slug
    before_action :set_current_project, except: %i[ index new create ]
    # the exports authorize after their scoped lookup, a refused export is a 404
    before_action :authorize_project, except: %i[ index new create export_csv export_days_csv ]
    before_action :set_participants, only: %i[ edit update ]

    # the lists are scoped, creating is not
    skip_verify_authorized only: :index
    skip_verify_authorized_scoped only: %i[ new create ]

    def show
      @project = current_project
      @entries_count = @project.entries.size
      @participating = current_member.participations.exists?(project: @project)
      @view = view

      @exportable = allowed_to?(:export?, @project)
      @manageable = allowed_to?(:manage?, @project)

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

    # archived projects are only listed for those who could unarchive them
    def index
      @projects = authorized_scope(current_org.projects).active.order(:name)
      @archived_projects = authorized_scope(current_org.projects, as: :manageable).archived.order(:name)
    end

    def new
      authorize!

      @project = current_org.projects.new
    end

    def create
      authorize!

      @project = current_org.projects.new(project_params)

      if @project.save
        redirect_to edit_project_path(current_org, @project), notice: t("controllers.projects.created", name: @project.name)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @project = current_project
    end

    # renames the project, the slug stays so links keep working
    def update
      # a copy, so a refused name does not show up in the switcher
      @project = current_org.projects.find(current_project.id)
      old_name = @project.name

      if @project.update(project_params)
        redirect_to edit_project_path(current_org, @project),
          notice: t("controllers.projects.renamed", old_name:, name: @project.name)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def archive
      current_project.archive!

      redirect_to project_path(current_org, current_project),
        notice: t("controllers.projects.archived", name: current_project.name)
    end

    def unarchive
      current_project.unarchive!

      redirect_to project_path(current_org, current_project),
        notice: t("controllers.projects.unarchived", name: current_project.name)
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

    # show? or manage?, see the aliases in ProjectPolicy
    def authorize_project
      authorize! current_project
    end

    # for the participants on the edit page, candidates are the active members who do not take part yet
    def set_participants
      @participants = current_project.participants.includes(:member).order("member.name")
      @candidates = current_org.members.active.where.not(id: @participants.select(:member_id)).order(:name)
    end

    def project_params
      params.expect(project: [ :name ])
    end

    # a project the member may read but not export is a 404 as well
    def exportable_project
      authorize! authorized_scope(current_org.projects, as: :exportable).find(current_project.id)
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
