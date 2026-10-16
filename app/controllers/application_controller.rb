class ApplicationController < ActionController::Base
  include RequestContext # sets the Current.objects, based on the request
  include Authentication # sets current_user, Rails' generated session handling
  include OrgScope # sets current_org & current_member, provides switch_current_org / go_solo
  include ProjectScope # sets current_project, provides switch_current_project
  include Authorization # ActionPolicy on behalf of current_member, renders a 403 when a policy refuses

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # the user's own memberships, and the 404 page
  skip_verify_authorized only: %i[ home error_404 ]
  skip_verify_authorized_scoped only: %i[ home error_404 ]

  def error_404
    render :error_404, status: :not_found
  end

  # today in the project the user worked in last, else their orgs and projects
  def home
    landing = LandingService.call(user: current_user)
    return redirect_to edit_day_path(landing.org, landing.project, Time.zone.today) if landing.project

    @memberships = current_user.memberships.active.includes(:org, participations: :project).sort_by { it.org.name }

    render :home, status: :ok
  end
end
