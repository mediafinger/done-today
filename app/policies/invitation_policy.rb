# Org managers and owners send, resend and revoke the org's invitations, a project's owners
#   those of its guests. Only owners invite as owner, or invite a deactivated owner back.
#   Only managers and owners bring a deactivated internal back, even as guest.
#   Ask with the change assigned.
#
class InvitationPolicy < ApplicationPolicy
  alias_rule :create?, :resend?, :destroy?, to: :manage?

  # managers and owners see the org's invitations, project leads the guest invitations of their projects
  relation_scope do |relation|
    next relation.none unless active?
    next relation.where(org_id: member.org_id) if org_manager?

    relation.where(project: authorized_scope(Project.all, as: :manageable))
  end

  def manage?
    return false if (owner_role? || record.to_deactivated_owner?) && !allowed_to?(:grant_owner?, Member)

    allowed_to?(:invite?, Member) || guest_of_their_project?
  end

  private

  def guest_of_their_project?
    record.guest? && record.project.present? && !record.to_deactivated_internal? &&
      allowed_to?(:invite_guest?, record.project)
  end
end
