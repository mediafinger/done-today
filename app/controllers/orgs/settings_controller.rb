module Orgs
  class SettingsController < ApplicationController
    def show
      @projects = ProjectPolicy.readable(current_member).order(:name)
    end

    def edit
    end
  end
end
