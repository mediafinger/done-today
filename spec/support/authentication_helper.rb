# Signs a user in the way the app does: POST /session, then pick org + project
# through the /open/:slug_org/:slug_project route that writes them onto the session.
#
module AuthenticationHelper
  def sign_in(user, password: "correct horse battery staple")
    post session_path, params: { email: user.email, password: }
  end

  def sign_in_and_open(participant, password: "correct horse battery staple")
    sign_in(participant.member.user, password:)
    get open_path(participant.project.org.slug, participant.project.slug)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
end
