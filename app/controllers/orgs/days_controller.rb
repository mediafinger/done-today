module Orgs
  class DaysController < ApplicationController
    def index
      if params[:date] # basically like show, but initializes a new day if none exists for the date
        @day =
          current_project.days.includes(entries: :member).find_by(date: params[:date]) ||
            current_project.days.build(org: current_org, date: params[:date])

        @entries = sorted_entries(@day)

        render :show
      elsif params[:member_id] # show all days of the current_project for the given member
        @members = current_project.members.order(name: :asc).pluck(:id, :name)
        @member = current_project.members.find(params[:member_id])
        @entries = current_project.entries.joins(:day).where(member: @member).order("day.date desc, entries.status desc", "entries.created_at asc")

        render :index_of_one_member
      else
        @days = current_project.days
      end
    end

    def show
      @day = Day.includes(entries: :member).find(params[:id])
      @entries = sorted_entries(@day)
    end

    private

    def sorted_entries(day)
      day.entries.joins(:member).order("entries.status desc", "members.name asc", "entries.created_at asc")
    end
  end
end
