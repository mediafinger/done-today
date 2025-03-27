module Orgs
  class DaysController < ApplicationController
    def index
    end

    def show
      @day = Day.find(params[:id])
    end
  end
end
