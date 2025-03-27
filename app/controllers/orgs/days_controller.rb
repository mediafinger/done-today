module Orgs
  class DaysController < ApplicationController
    def index
      if params[:date]
        @day =
          current_project.days.find_by(date: params[:date]) ||
            current_project.days.build(org: current_org, date: params[:date])

        render :show
      else
        @days = current_project.days
      end
    end

    def show
      @day = Day.find(params[:id])
    end
  end
end
