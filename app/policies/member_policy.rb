# Internals list the members of their org, org managers and owners manage them, themselves included.
#   Only owners give or take the owner role, so managers leave owners alone.
#   Ask with the Member class for the list, with a Member for changes, the change assigned.
#
class MemberPolicy < ApplicationPolicy
  # send, resend and revoke invitations to the org
  alias_rule :invite?, to: :manage?
  # roles, deactivate, reactivate
  alias_rule :update?, :deactivate?, :reactivate?, to: :manage?

  # the members of the own org, archived ones and guests included: index? and manage? decide
  #   who lists or changes them, so a guest gets the 403 of the rule, not a 404
  relation_scope do |relation|
    next relation.none unless active?

    relation.where(org_id: member.org_id)
  end

  # who a project manager may add to a project: the internals, and the guests of the projects they manage
  relation_scope(:addable) do |relation|
    next relation.none unless internal?
    next relation if org_manager?

    guests = Participant.where(project: authorized_scope(Project.all, as: :manageable)).select(:member_id)

    relation.internal.or(relation.guests.where(id: guests))
  end

  def index?
    internal?
  end

  def manage?
    org_manager? && (grant_owner? || !owner_role?)
  end

  # make someone an owner, also by invitation, or take the role
  def grant_owner?
    org_owner?
  end
end
