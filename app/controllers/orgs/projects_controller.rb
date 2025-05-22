module Orgs
  class ProjectsController < ApplicationController
    def show
      # TODO: only display:
      #  * projects the member is participant of
      #  * all projects of org, if the member role is owner

      @project = current_org.projects.find(params[:id])
      @entries_count = @project.entries.joins(:day).size
      @days =
        @project.days
          .includes(entries: :member)
          .order("days.date desc", "entries.status desc", "entries.member_id asc", "entries.created_at asc")
    end

    def index
      @projects = current_org.projects.order(:name)
    end
  end
end
