# Org managers and owners send, resend and revoke the org's invitations, a project's owners
#   those of its guests. Only owners invite as owner. Ask with the change assigned.
#
class InvitationPolicy < ApplicationPolicy
  alias_rule :create?, :resend?, :destroy?, to: :manage?

  def manage?
    return false if owner_role? && !allowed_to?(:grant_owner?, Member)

    allowed_to?(:invite?, Member) || guest_of_their_project?
  end

  private

  def guest_of_their_project?
    record.guest? && record.project.present? && allowed_to?(:invite_guest?, record.project)
  end
end
