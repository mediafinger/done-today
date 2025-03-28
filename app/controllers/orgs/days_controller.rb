module Orgs
  class DaysController < ApplicationController
    def index
      if params[:date]
        @day =
          current_project.days.includes(entries: :member).find_by(date: params[:date]) ||
            current_project.days.build(org: current_org, date: params[:date])

        @entries = sorted_entries(@day)

        render :show
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
