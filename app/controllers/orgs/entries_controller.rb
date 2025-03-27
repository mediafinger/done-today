module Orgs
  class EntriesController < ApplicationController
    def index
      @day = current_project.days.find_by(date: params[:date])
      @entries = @day.entries.where(member: current_member).order(status: :desc, created_at: :asc)
    end

    def create
      entry = Entry.new(
        org: current_org,
        member: current_member,
        day_id: create_params[:day_id], # hidden field in form
        log: create_params[:log],
        status: create_params[:status] || "todo", # TODO
      )

      entry.save!

      redirect_to entries_path(date: entry.day.date)
    end

    def update
      entry = current_project.entries.find(params[:id])

      entry.status = update_params[:status]  if update_params[:status].present?
      entry.log    = update_params[:log]     if update_params[:log].present?

      entry.save!

      redirect_to entries_path(date: entry.day.date)
    end

    private

    def create_params
      params.require(:entry).permit(:day_id, :log, :status)
    end

    def update_params
      params.require(:entry).permit(:log, :status)
    end
  end
end
