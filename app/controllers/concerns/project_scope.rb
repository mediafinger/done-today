# The project is the second segment of the path, /:org_slug/:project_slug/...,
#   looked up among the projects the member may read: anything else is a 404.
#
module ProjectScope
  extend ActiveSupport::Concern

  included do
    helper_method :current_project if respond_to? :helper_method
  end

  private

  def set_current_project
    Current.project = authorized_scope(current_org.projects).find_by!(slug: params[:project_slug])
  end

  # nil outside of a project's pages
  def current_project
    Current.project
  end
end
