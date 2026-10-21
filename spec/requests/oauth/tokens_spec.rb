require "rails_helper"

# Doorkeeper's token endpoint: OAuth 2.1 for public clients only (#109)
RSpec.describe "OAuth tokens" do
  let(:application) { Doorkeeper::Application.create!(name: "AI app", redirect_uri: "https://ai.example/callback", confidential: false) }

  it "issues no token for client credentials, even to a client with a secret" do
    client = Doorkeeper::Application.create!(name: "Server app", redirect_uri: "https://ai.example/callback", confidential: true)

    post "/oauth/token", params: { grant_type: "client_credentials", client_id: client.uid, client_secret: client.plaintext_secret }

    expect(response.parsed_body).to include("error" => "unsupported_grant_type")
  end

  it "issues no token for a password" do
    user = create(:user)

    post "/oauth/token", params: { grant_type: "password", client_id: application.uid, username: user.email, password: "correct horse battery staple" }

    expect(response.parsed_body).not_to have_key("access_token")
  end

  it "has no introspection endpoint" do
    expect(Rails.application.routes.recognize_path("/oauth/introspect", method: :post)).to include(action: "error_404")
  end
end
