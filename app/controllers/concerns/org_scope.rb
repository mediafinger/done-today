module OrgScope
  extend ActiveSupport::Concern

  included do
    helper_method :current_org if respond_to? :helper_method
    helper_method :current_member if respond_to? :helper_method
  end

  def switch_current_org(org_id)
    raise ActiveRecord::RecordNotFound.new("User not persisted", current_user, :id) unless current_user.persisted?

    org = current_user.orgs.find(org_id)
    refresh_current_session(org:)

    Current.org
  end

  def go_solo
    refresh_current_session(org: nil)

    true
  end

  private

  def refresh_current_session(org:)
    Current.session.update!(org:)

    Current.org = org
    Current.member = org.nil? ? nil : current_user.memberships.find_by!(org:)
  end

  def current_org
    Current.org ||=
      if Current.session.org && current_user.orgs.exists?(id: Current.session.org)
        Current.session.org
      end # else nil
  end

  def current_member
    Current.member ||= current_user.memberships.find_by!(org: current_org) if current_org
  end
end
