require "rails_helper"

# the link mailed to the new address, it works without a session
RSpec.describe "Users::UserEmailConfirmations" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, email: "anna@example.com").tap { it.update!(unconfirmed_email: "bell@example.com") } }
  let(:token) { user.generate_token_for(:email_confirmation) }

  it "asks to confirm the new address, without changing it yet" do
    get user_email_confirmation_path(token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("bell@example.com")
    expect(user.reload.email).to eq("anna@example.com")
  end

  it "changes the email" do
    patch user_email_confirmation_path(token)

    expect(response).to redirect_to(new_session_path)
    expect(user.reload).to have_attributes(email: "bell@example.com", unconfirmed_email: nil)
  end

  it "takes a signed-in user back to the account page" do
    sign_in(user)

    patch user_email_confirmation_path(token)

    expect(response).to redirect_to(edit_user_path)
  end

  it "refuses the link a second time" do
    patch user_email_confirmation_path(token)
    patch user_email_confirmation_path(token)

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to include("invalid or has expired")
  end

  {
    "an expired link" => -> { token.tap { travel(User::EMAIL_CONFIRMATION_EXPIRES_IN + 1.second) } },
    "the link of a cancelled change" => -> { token.tap { user.update!(unconfirmed_email: nil) } },
    "a forged link" => -> { "forged" }
  }.each do |refused, link|
    it "refuses #{refused}" do
      get user_email_confirmation_path(instance_exec(&link))

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.email).to eq("anna@example.com")
    ensure
      travel_back
    end
  end

  it "refuses an address somebody else took meanwhile" do
    token
    create(:user, email: "bell@example.com")

    patch user_email_confirmation_path(token)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email has already been taken")
    expect(user.reload.email).to eq("anna@example.com")
  end
end
