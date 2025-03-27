class ApplicationController < ActionController::Base
  include Authentication
  include OrgScope # sets current_org & current_member, provides switch_current_org / go_solo
  include ProjectScope # sets current_project, provides switch_current_project
  include RequestContext # sets the Current.objects, partly based on current_user and current_org

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def error_404
    render :error_404, status: :not_found
  end

  def home
    render :home, status: :ok
  end
end
