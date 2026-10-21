require "rails_helper"

# The consent page: the user picks what a hosted AI app may reach (#109)
RSpec.describe "OAuth consent" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:participant, project:).member }
  let(:user) { member.user }
  let(:client) { oauth_app }

  def approve(grants, **overrides)
    post "/oauth/authorize", params: oauth_authorize_params(client, **overrides).merge(grants:)
  end

  def redirect_params
    Rack::Utils.parse_query(URI.parse(response.location).query)
  end

  describe "GET /oauth/authorize" do
    it "asks to sign in first and comes back afterwards" do
      get "/oauth/authorize", params: oauth_authorize_params(client)

      expect(response).to redirect_to(new_session_path)

      sign_in(user)

      expect(response).to redirect_to(%r{/oauth/authorize\?client_id=#{client.uid}})
    end

    it "shows the app, where it sends the user back, and the grant fields" do
      sign_in(user)

      get "/oauth/authorize", params: oauth_authorize_params(client)

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#oauth-consent").text).to include("AI app", "ai.example")
      expect(page.at_css("select[name='grants[orgs][#{org.id}]']")).to be_present
      expect(page.at_css("select[name='grants[projects][#{project.id}]']")).to be_present
      expect(page.css("select option[selected]").map { it["value"] }).to all(be_blank)
    end

    it "offers only read access when the app asks for no more" do
      sign_in(user)

      get "/oauth/authorize", params: oauth_authorize_params(oauth_app(scopes: "entries:read"))

      values = Nokogiri::HTML(response.body).css("select[name^='grants'] option").map { it["value"] }.uniq
      expect(values).to contain_exactly("", "read")
    end

    it "can't be framed" do
      sign_in(user)

      get "/oauth/authorize", params: oauth_authorize_params(client)

      expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors 'none'")
    end

    it "refuses another resource than the MCP server" do
      sign_in(user)

      get "/oauth/authorize", params: oauth_authorize_params(client, resource: "https://other.example/mcp")

      expect(response).to have_http_status(:bad_request)
      expect(Nokogiri::HTML(response.body).at_css("#oauth-consent")).to be_nil
    end

    it "refuses a redirect URI the app didn't register, without redirecting" do
      sign_in(user)

      get "/oauth/authorize", params: oauth_authorize_params(client, redirect_uri: "https://evil.example/callback")

      expect(response).not_to be_redirect
      expect(Nokogiri::HTML(response.body).at_css("#oauth-consent")).to be_nil
    end

    it "refuses a request without PKCE" do
      sign_in(user)

      get "/oauth/authorize", params: oauth_authorize_params(client, code_challenge: nil, code_challenge_method: nil)

      expect(Nokogiri::HTML(response.body).at_css("#oauth-consent")).to be_nil
    end
  end

  describe "POST /oauth/authorize" do
    before { sign_in(user) }

    it "connects the app with the chosen grants and sends the code back" do
      expect { approve({ projects: { project.id => "write" } }) }.to change(TokenAuth::Connection, :count).by(1)

      expect(response.location).to start_with(OauthRequests::OAUTH_REDIRECT_URI)
        .and include("state=s1", "code=")

      connection = TokenAuth::Connection.last
      expect(connection).to have_attributes(user:, oauth_application: client, name: "AI app")
      expect(connection.grants.sole).to have_attributes(project:, access: "write")
      expect(Doorkeeper::AccessGrant.last.connection_id).to eq(connection.id)
    end

    it "issues a token for the connection, which reaches /mcp" do
      approve({ orgs: { org.id => "read" } })

      token = oauth_exchange(client, oauth_code)
      expect(token).to include("token_type" => "Bearer", "access_token" => start_with("done_oat_"), "refresh_token" => be_present)

      mcp("tools/call", { name: "list_projects", arguments: {} }, token: token["access_token"])
      expect(tool_data).to contain_exactly(include("project" => project.slug, "access" => "read"))
    end

    it "needs at least one grant" do
      expect { approve({ orgs: { org.id => "" } }) }.not_to change(TokenAuth::Connection, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("#oauth-consent")).to be_present
    end

    it "drops orgs and projects the user doesn't take part in" do
      foreign = create(:org)

      expect { approve({ orgs: { foreign.id => "write" } }) }.not_to change(TokenAuth::Connection, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "caps the grants at read when the app asked for read only" do
      read_only = oauth_app(scopes: "entries:read")

      post "/oauth/authorize", params: oauth_authorize_params(read_only).merge(grants: { orgs: { org.id => "write" } })

      expect(TokenAuth::Connection.last.grants.sole.access).to eq("read")
    end

    it "ignores a connection the client names" do
      other = create(:token_auth_connection)

      approve({ orgs: { org.id => "read" } }, connection_id: other.id)

      connection_id = Doorkeeper::AccessGrant.last.connection_id
      expect(connection_id).not_to eq(other.id)
      expect(TokenAuth::Connection.find(connection_id).user).to eq(user)
    end

    it "replaces an earlier connection of the same app" do
      approve({ orgs: { org.id => "read" } })
      earlier = TokenAuth::Connection.last

      approve({ orgs: { org.id => "write" } })

      expect(earlier.reload).to be_revoked
      expect(user.token_auth_connections.active.sole.grants.sole.access).to eq("write")
    end

    it "refuses another resource than the MCP server" do
      expect { approve({ orgs: { org.id => "read" } }, resource: "https://other.example/mcp") }
        .not_to change(TokenAuth::Connection, :count)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /oauth/authorize" do
    it "sends the user back with access_denied and connects nothing" do
      sign_in(user)

      expect { delete "/oauth/authorize", params: oauth_authorize_params(client) }.not_to change(TokenAuth::Connection, :count)

      expect(redirect_params).to include("error" => "access_denied", "state" => "s1")
    end
  end
end
