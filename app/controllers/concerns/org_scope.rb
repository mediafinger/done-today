module OrgScope
  extend ActiveSupport::Concern

  included do
    helper_method :current_org if respond_to? :helper_method
    helper_method :current_member if respond_to? :helper_method
  end

  def switch_current_org(org_id)
    return unless current_user

    raise ActiveRecord::RecordNotFound.new("User not persisted", current_user, :id) unless current_user.persisted?

    org = active_memberships.find_by!(org_id:).org
    refresh_current_session(org:)

    Current.org
  end

  def go_solo
    return unless current_user

    refresh_current_session(org: nil)

    true
  end

  private

  # an archived membership no longer opens its org
  def active_memberships
    current_user.memberships.active
  end

  def refresh_current_session(org:)
    Current.session.update!(org:)

    Current.org = org
    Current.member = org.nil? ? nil : active_memberships.find_by!(org:)
  end

  def current_org
    Current.org ||=
      if Current.session&.org && current_user && active_memberships.exists?(org: Current.session.org)
        Current.session.org
      end # else nil
  end

  def current_member
    Current.member ||= active_memberships.find_by!(org: current_org) if current_org
  end
end
