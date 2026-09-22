module Orgs
  class ProjectsController < AppOrgBaseController
    VIEWS = %w[days weeks].freeze

    def show
      # TODO: only display:
      #  * projects the member is participant of
      #  * all projects of org, if the member role is owner

      @project = current_org.projects.find_by!(slug: params[:slug])
      @entries_count = @project.entries.size
      @view = view

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
        # the week view sums up each member's time and tags instead of listing entries
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

    private

    # an unknown view falls back to the days, rather than raising
    def view
      params[:view].presence_in(VIEWS) || "days"
    end
  end
end
