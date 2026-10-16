# Signs a user in the way the app does: POST /session. Org and project are part of
#   every path after that, nothing is selected.
#
module AuthenticationHelper
  def sign_in(user, password: "correct horse battery staple")
    post session_path, params: { email: user.email, password: }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
end
