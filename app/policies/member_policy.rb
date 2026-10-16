# Org owners manage the members of their org, themselves included.
#   Ask with the Member class for the list, with a Member for changes.
#
class MemberPolicy < ApplicationPolicy
  def index?
    self.class.org_owner?(member)
  end

  # send, resend and revoke invitations to the org
  def invite?
    index?
  end

  # roles, deactivate, reactivate
  def manage?
    index? && record.org_id == member.org_id
  end
end
