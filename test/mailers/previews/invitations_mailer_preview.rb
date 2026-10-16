class InvitationsMailerPreview < ActionMailer::Preview
  # Preview this email at /rails/mailers/invitations_mailer/invite
  def invite
    InvitationsMailer.invite(Invitation.take || Invitation.new(org: Org.take, email: "invitee@example.com", sent_at: Time.current))
  end
end
