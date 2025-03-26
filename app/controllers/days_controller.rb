class DaysController < ApplicationController
  before_action :require_authentication

  def show
    @day = Day.find(params[:id])
  end

  def index
  end
end
