class AccessRequestsMailer < ApplicationMailer
  # to one of AccessRequest#recipients
  def requested(access_request, recipient)
    @access_request = access_request
    @url = edit_project_url(access_request.org, access_request.project)

    mail subject: "#{access_request.member.name} asks to join #{access_request.project.name}", to: recipient.user.email
  end
end
