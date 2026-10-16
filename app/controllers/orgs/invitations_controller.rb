module Orgs
  # Org owners invite people by email, and resend or revoke pending invitations.
  #   The invitee accepts in Users::InvitationsController.
  #
  class InvitationsController < AppOrgBaseController
    include InvitationSending

    before_action { authorize! Member, to: :invite? }
    # invitations are looked up in current_org, only owners get here
    skip_verify_authorized_scoped

    rate_limit to: 20, within: 1.hour, only: %i[ create resend ], by: -> { current_member.id },
      with: -> { redirect_to members_path(current_org), alert: t("controllers.invitations.rate_limited") }

    # inviting a pending email again sends it with the new role, and kills the old link
    def create
      attributes = params.expect(invitation: %i[ email name role project_id project_role ])
      invitation = current_org.invitations.pending.find_or_initialize_by(email: attributes[:email])
      invitation.assign_attributes(name: attributes[:name], role: attributes[:role], **guest_attributes(attributes))

      send_invitation(invitation, :sent, back: members_path(current_org))
    end

    def resend
      send_invitation(invitation, :resent, back: members_path(current_org))
    end

    def destroy
      invitation.destroy!

      redirect_to members_path(current_org), notice: t("controllers.invitations.revoked", email: invitation.email)
    end

    private

    def invitation
      @invitation ||= current_org.invitations.pending.find(params[:id])
    end

    # only guests are invited to a project
    def guest_attributes(attributes)
      return { project: nil, project_role: nil } unless attributes[:role] == "guest"

      { project: current_org.projects.find_by(id: attributes[:project_id]), project_role: attributes[:project_role] }
    end
  end
end
