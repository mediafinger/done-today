# Sends an invitation, or sends it again: a new sent_at invalidates the links sent before.
#
module InvitationSending
  extend ActiveSupport::Concern

  private

  def send_invitation(invitation, done, back:)
    if invitation.update(invited_by: current_member, sent_at: Time.current)
      InvitationsMailer.invite(invitation).deliver_later

      redirect_to back, notice: t("controllers.invitations.#{done}", email: invitation.email)
    else
      redirect_to back, alert: invitation.errors.full_messages.to_sentence
    end
  end
end
