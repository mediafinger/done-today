require "rails_helper"

# A hosted AI app connects to done from scratch, as the MCP authorization spec describes (#109):
#   challenge → metadata → registration → consent → token → /mcp → refresh → disconnect
#
RSpec.describe "OAuth end to end" do
  let(:participation) { create(:participant) }
  let(:project) { participation.project }
  let(:user) { participation.member.user }

  def register
    post "/oauth/register", params: { client_name: "AI app", redirect_uris: [ OauthRequests::OAUTH_REDIRECT_URI ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    Doorkeeper::Application.find_by!(uid: response.parsed_body.fetch("client_id"))
  end

  def path_of(url) = URI.parse(url).path

  # from /mcp's 401 to the authorization server's metadata, as a client finds it
  def discover
    mcp("tools/list", token: nil)
    get path_of(response.headers["WWW-Authenticate"][/resource_metadata="([^"]+)"/, 1])
    get "#{path_of(response.parsed_body.fetch("authorization_servers").first)}/.well-known/oauth-authorization-server"
    response.parsed_body
  end

  # registration, consent and code exchange: the tokens the app holds
  def connect(server, client = register)
    sign_in(user)
    post path_of(server.fetch("authorization_endpoint")),
      params: oauth_authorize_params(client).merge(grants: { projects: { project.id => "write" } })
    [ client, oauth_exchange(client, oauth_code) ]
  end

  def refresh(server, client, refresh_token)
    post path_of(server.fetch("token_endpoint")), params: { grant_type: "refresh_token", client_id: client.uid, refresh_token: }
    response.parsed_body
  end


  it "finds every endpoint from /mcp's challenge" do
    expect(discover.values_at("authorization_endpoint", "token_endpoint", "registration_endpoint").map { path_of(it) })
      .to eq(%w[/oauth/authorize /oauth/token /oauth/register])
  end

  it "connects an app whose token reaches /mcp, also after a refresh" do
    server = discover
    client, tokens = connect(server)

    mcp("tools/call", { name: "list_projects", arguments: {} }, token: tokens.fetch("access_token"))
    expect(tool_data).to contain_exactly(include("project" => project.slug, "access" => "write"))

    mcp("tools/list", token: refresh(server, client, tokens.fetch("refresh_token")).fetch("access_token"))
    expect(response).to have_http_status(:ok)
  end

  it "ends the app's access and its refresh on disconnect" do
    server = discover
    client, tokens = connect(server)

    delete user_access_token_path(user.token_auth_connections.sole)

    mcp("tools/list", token: tokens.fetch("access_token"))
    expect(response).to have_http_status(:unauthorized)
    expect(refresh(server, client, tokens.fetch("refresh_token"))).to include("error" => "invalid_grant")
  end

  describe "a token request that doesn't match the authorization" do
    let(:client) { register }
    let!(:code) do
      sign_in(user)
      post "/oauth/authorize", params: oauth_authorize_params(client).merge(grants: { projects: { project.id => "read" } })
      oauth_code
    end

    def exchange(**overrides)
      post "/oauth/token", params: {
        grant_type: "authorization_code", client_id: client.uid, code:, redirect_uri: OauthRequests::OAUTH_REDIRECT_URI,
        code_verifier: OauthRequests::OAUTH_VERIFIER
      }.merge(overrides).compact
      response.parsed_body
    end

    it "is refused with another redirect URI" do
      expect(exchange(redirect_uri: "https://ai.example/other")).to include("error" => "invalid_grant")
    end

    it "is refused without the PKCE verifier, or with another one" do
      expect(exchange(code_verifier: nil)).to include("error" => be_present)
      expect(exchange(code_verifier: "x" * 50)).to include("error" => "invalid_grant")
    end

    it "is refused for another client" do
      expect(exchange(client_id: register.uid)).to include("error" => "invalid_grant")
    end

    it "is refused the second time" do
      exchange

      expect(exchange).to include("error" => "invalid_grant")
    end

    it "is refused once the code expired" do
      Doorkeeper::AccessGrant.update_all(created_at: 11.minutes.ago)

      expect(exchange).to include("error" => "invalid_grant")
    end
  end
end
