require "rails_helper"

# the link mailed to the old address, it works without a session
RSpec.describe "Users::UserEmailReverts" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, email: "anna@example.com").tap { it.update!(unconfirmed_email: "bell@example.com") } }
  let!(:token) { user.email_revert_token }

  it "offers to cancel a pending change" do
    get user_email_revert_path(token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cancel the change")
  end

  it "cancels a pending change" do
    patch user_email_revert_path(token)

    expect(response).to redirect_to(new_session_path)
    expect(user.reload).to have_attributes(email: "anna@example.com", unconfirmed_email: nil)
  end

  context "when the change is confirmed" do
    before { user.confirm_email_change }

    it "offers to restore the old address" do
      get user_email_revert_path(token)

      expect(response.body).to include("Restore anna@example.com")
    end

    it "restores the old address and signs out everywhere, this browser too" do
      sign_in(user)

      patch user_email_revert_path(token)

      expect(response).to redirect_to(new_password_path)
      expect(user.reload.email).to eq("anna@example.com")
      expect(user.sessions).to be_empty
      expect(cookies[:session_id]).to be_blank
    end
  end

  {
    "an expired link" => -> { token.tap { travel(User::EMAIL_REVERT_EXPIRES_IN + 1.second) } },
    "a used link" => -> { token.tap { user.update!(unconfirmed_email: nil) } },
    "a forged link" => -> { "forged" }
  }.each do |refused, link|
    it "refuses #{refused}" do
      get user_email_revert_path(instance_exec(&link))

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include("invalid or has expired")
    ensure
      travel_back
    end
  end
end
