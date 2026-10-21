require "rails_helper"

# A refresh keeps an app connected only while the connection still gives access (#109)
RSpec.describe "OAuth refresh" do
  let(:participation) { create(:participant) }
  let(:client) { oauth_app }
  let(:connection) { TokenAuth::Connection.find_by!(oauth_application: client) }

  # the tokens the app holds after the user approved
  let!(:tokens) do
    sign_in(participation.member.user)
    post "/oauth/authorize", params: oauth_authorize_params(client).merge(grants: { orgs: { participation.project.org_id => "write" } })
    oauth_exchange(client, oauth_code)
  end

  def refresh(refresh_token = tokens["refresh_token"])
    post "/oauth/token", params: { grant_type: "refresh_token", client_id: client.uid, refresh_token: }
    response.parsed_body
  end

  it "issues a new token for the same connection, with a new refresh token" do
    refreshed = refresh

    expect(refreshed).to include("access_token" => start_with("done_oat_"), "refresh_token" => be_present)
    expect(refreshed["refresh_token"]).not_to eq(tokens["refresh_token"])
    expect(TokenAuth::Connection.authenticate(refreshed["access_token"])).to eq(connection)
  end

  it "refuses once the user disconnected the app" do
    connection.revoke!

    expect(refresh).to include("error" => "invalid_grant")
    expect(response).to have_http_status(:bad_request)
  end

  it "refuses once no grant has effect, e.g. after leaving the project" do
    participation.destroy!

    expect(refresh).to include("error" => "invalid_grant")
  end

  it "refuses a refresh token older than 30 days" do
    connection.access_tokens.update_all(created_at: 31.days.ago)

    expect(refresh).to include("error" => "invalid_grant")
  end

  it "refuses a refresh token that was rotated and used" do
    refreshed = refresh
    mcp("tools/list", token: refreshed["access_token"])

    expect(refresh(tokens["refresh_token"])).to include("error" => "invalid_grant")
  end

  it "refuses an unknown refresh token" do
    expect(refresh("no-such-token")).to include("error" => "invalid_grant")
  end
end
