module Orgs
  # Org owners invite people by email, and resend or revoke pending invitations.
  #   The invitee accepts in Users::InvitationsController.
  #
  class InvitationsController < AppOrgBaseController
    before_action { authorize! Member, to: :invite? }

    rate_limit to: 20, within: 1.hour, only: %i[ create resend ], by: -> { current_member.id },
      with: -> { redirect_to members_path(current_org), alert: t("controllers.invitations.rate_limited") }

    # inviting a pending email again sends it with the new roles, and kills the old link
    def create
      attributes = params.expect(invitation: [ :email, :name, roles: [] ])
      invitation = current_org.invitations.pending.find_or_initialize_by(email: attributes[:email])
      invitation.assign_attributes(name: attributes[:name], roles: Array(attributes[:roles]).compact_blank)

      send_invitation(invitation, :sent)
    end

    def resend
      send_invitation(invitation, :resent)
    end

    def destroy
      invitation.destroy!

      redirect_to members_path(current_org), notice: t("controllers.invitations.revoked", email: invitation.email)
    end

    private

    def invitation
      @invitation ||= current_org.invitations.pending.find(params[:id])
    end

    # a new sent_at invalidates the links sent before
    def send_invitation(invitation, done)
      if invitation.update(invited_by: current_member, sent_at: Time.current)
        InvitationsMailer.invite(invitation).deliver_later

        redirect_to members_path(current_org), notice: t("controllers.invitations.#{done}", email: invitation.email)
      else
        redirect_to members_path(current_org), alert: invitation.errors.full_messages.to_sentence
      end
    end
  end
end
