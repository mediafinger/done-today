# Org owners manage the members of their org, themselves included.
#   Ask with the Member class for the list, with a Member for changes.
#
class MemberPolicy < ApplicationPolicy
  # send, resend and revoke invitations to the org
  alias_rule :invite?, to: :index?
  # roles, deactivate, reactivate
  alias_rule :update?, :deactivate?, :reactivate?, to: :manage?

  def index?
    org_owner?
  end

  def manage?
    org_owner?
  end
end
