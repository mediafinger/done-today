class InvitationsMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @url = accept_invitation_url(invitation.generate_token_for(:acceptance))

    mail subject: "Join #{invitation.org.name} on Done today", to: invitation.email
  end
end
