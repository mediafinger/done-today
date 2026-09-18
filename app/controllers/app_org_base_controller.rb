# Base class for the controllers under the /orgs namespace.
#
# They all query through `current_org` / `current_project`, which stay nil until the
#   user opens an org via /open/:slug_org(/:slug_project). A freshly created Session
#   carries neither, so this is exactly the state a user is in right after signing in
#   -- and without these guards every such action raised NoMethodError on nil.
#
class AppOrgBaseController < ApplicationController
  before_action :require_member

  private

  def require_member
    return if current_member.present?

    redirect_to root_path, alert: t("controllers.no_org_selected")
  end

  # Opt-in for the actions that need a concrete project, not just an org.
  #   Subclasses provide `project`.
  #
  def require_project
    return if project.present?

    redirect_to projects_path, alert: t("controllers.no_project_selected")
  end
end
