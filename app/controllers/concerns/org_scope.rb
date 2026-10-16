# The org is the first segment of the path, /:org_slug/..., looked up through the
#   user's active memberships: an unknown org, someone else's org and an org they
#   were deactivated in are the same 404.
#
module OrgScope
  extend ActiveSupport::Concern

  included do
    helper_method :current_org if respond_to? :helper_method
    helper_method :current_member if respond_to? :helper_method
  end

  private

  def set_current_org
    Current.member = current_user.memberships.active.joins(:org).find_by!(org: { slug: params[:org_slug] })
    Current.org = Current.member.org
  end

  # nil outside of an org's pages
  def current_org
    Current.org
  end

  def current_member
    Current.member
  end
end
