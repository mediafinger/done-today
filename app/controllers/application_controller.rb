class ApplicationController < ActionController::Base
  include RequestContext # sets the Current.objects, based on the request
  include Authentication # sets current_user, Rails' generated session handling
  include OrgScope # sets current_org & current_member, provides switch_current_org / go_solo
  include ProjectScope # sets current_project, provides switch_current_project
  include Authorization # ActionPolicy on behalf of current_member, renders a 403 when a policy refuses

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def error_404
    render :error_404, status: :not_found
  end

  # nothing is selected after signing in: the user's orgs and their projects
  def home
    @memberships = current_user.memberships.active.includes(:org, participations: :project).sort_by { it.org.name }

    render :home, status: :ok
  end
end
