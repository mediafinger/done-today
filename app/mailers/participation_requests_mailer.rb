class ParticipationRequestsMailer < ApplicationMailer
  # to one of ParticipationRequest#recipients
  def requested(participation_request, recipient)
    @participation_request = participation_request
    @url = edit_project_url(participation_request.org, participation_request.project)

    mail subject: "#{participation_request.member.name} asks to join #{participation_request.project.name}", to: recipient.user.email
  end
end
