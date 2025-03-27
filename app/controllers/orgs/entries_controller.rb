module Orgs
  class EntriesController < ApplicationController
    # when no day for the selected date exists yet, we initialize a new day,
    #   so the user can start typing a log immediately
    #
    def index
      @day =
        current_project.days.find_by(date: params[:date]) ||
          current_project.days.build(org: current_org, date: params[:date])
      @entries = @day.entries.where(member: current_member).order(status: :desc, created_at: :asc)
    end

    # create_params[:date] is coming from a hidden form field and contains either
    #   the day's date or the date given in the URL.
    #   Therefore we need to find or create a day for the given date.
    #
    def create
      entry = Entry.new(
        org: current_org,
        member: current_member,
        day: current_project.days.find_or_create_by!(org: current_org, date: create_params[:date]),
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
      params.require(:entry).permit(:date, :log, :status)
    end

    def update_params
      params.require(:entry).permit(:log, :status)
    end
  end
end
