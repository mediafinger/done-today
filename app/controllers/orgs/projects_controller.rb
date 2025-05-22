module Orgs
  class ProjectsController < ApplicationController
    def show
      # TODO: only display:
      #  * projects the member is participant of
      #  * all projects of org, if the member role is owner

      @project = current_org.projects.find(params[:id])
      @entries_count = @project.entries.size

      @with_date = true
      @with_project = false
      @with_member = true

      # ONE project, many days
      @days =
        @project.days
          .includes(entries: :member)
          .order("days.date desc", "entries.status desc", "entries.member_id asc", "entries.created_at asc")

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
      if current_org
        @projects = current_org.projects.order(:name)
      else
        redirect_to root_path, notice: "Select an org first"
      end
    end
  end
end
