module Orgs
  # Org and project owners invite guests (externals) to the project, and resend or
  #   revoke those invitations. The invitee accepts in Users::InvitationsController.
  #
  class GuestInvitationsController < AppOrgBaseController
    include InvitationSending

    before_action :set_current_project
    before_action { authorize! current_project, to: :invite_guest? }

    rate_limit to: 20, within: 1.hour, only: %i[ create resend ], by: -> { current_member.id },
      with: -> { redirect_to back_path, alert: t("controllers.invitations.rate_limited") }

    # inviting a pending guest of the project again sends it with the new role, and kills the old link
    def create
      attributes = params.expect(invitation: %i[ email name project_role ])
      invitation = current_org.invitations.pending.find_or_initialize_by(email: attributes[:email])

      # an org owner decides what somebody invited to the org or another project becomes
      if invitation.persisted? && invitation.project != current_project
        return redirect_to back_path, alert: t("controllers.invitations.already_invited", email: invitation.email)
      end

      invitation.assign_attributes(
        name: attributes[:name], role: "guest", project: current_project, project_role: attributes[:project_role]
      )

      send_invitation(invitation, :sent, back: back_path)
    end

    def resend
      send_invitation(invitation, :resent, back: back_path)
    end

    def destroy
      invitation.destroy!

      redirect_to back_path, notice: t("controllers.invitations.revoked", email: invitation.email)
    end

    private

    def invitation
      @invitation ||= current_project.invitations.pending.find(params[:id])
    end

    def back_path
      edit_project_path(current_org, current_project)
    end
  end
end
