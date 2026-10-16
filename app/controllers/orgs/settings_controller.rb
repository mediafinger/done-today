module Orgs
  # The user's settings on /settings, with an org's on /:org_slug/settings.
  #
  class SettingsController < ApplicationController
    before_action :set_current_org, if: -> { params[:org_slug] }

    # the user's own settings, the projects are scoped
    skip_verify_authorized

    def show
      @projects = authorized_scope(Project.all).active.order(:name)
      @orgs = current_user.orgs.merge(Member.active).order(:name)
    end
  end
end
