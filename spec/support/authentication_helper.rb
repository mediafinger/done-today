# Signs a user in the way the app does: POST /session. Org and project are part of
#   every path after that, nothing is selected.
#
module AuthenticationHelper
  def sign_in(user, password: "correct horse battery staple")
    post session_path, params: { email: user.email, password: }
  end
end

# The same through the sign-in form, for the browser of a system spec
#
module SystemAuthenticationHelper
  def sign_in(user, password: "correct horse battery staple")
    visit new_session_path
    fill_in placeholder: "Enter your email address", with: user.email
    fill_in placeholder: "Enter your password", with: password
    click_button "Sign in"

    expect(page).to have_no_button("Sign in")
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include SystemAuthenticationHelper, type: :system
end
