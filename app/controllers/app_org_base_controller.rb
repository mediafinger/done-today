class AppOrgBaseController < ApplicationController
  before_action :require_member

  private

  def require_member
    return true if current_member.present?

    redirect_to root_path, alert: I18n.t("helpers.controller.unauthorized")
  end
end
