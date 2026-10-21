require "rails_helper"

RSpec.describe "Mcp::Server" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:user) { member.user }
  let(:secret) { personal_token(user, org => "write") }

  before do
    host! AppConf.done_host
    create(:participant, project:, member:)
  end

  describe "authentication" do
    it "refuses a request without a token with a Bearer challenge" do
      mcp("tools/list", token: nil)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
    end

    it "refuses an unknown token" do
      mcp("tools/list", token: "done_pat_unknown")

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include("invalid_token")
    end

    it "refuses a revoked token" do
      secret
      user.token_auth_connections.revoke_all!

      mcp("tools/list")

      expect(response).to have_http_status(:unauthorized)
    end

    it "ignores the cookie session" do
      sign_in(user)

      mcp("tools/list", token: nil)

      expect(response).to have_http_status(:unauthorized)
    end

    it "notes the token's use" do
      mcp("tools/list")

      expect(user.token_auth_connections.sole.last_used_at).to be_present
    end
  end

  it "answers the handshake" do
    mcp("initialize", { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "spec", version: "1" } })

    expect(response).to have_http_status(:ok)
    expect(mcp_result.dig("serverInfo", "name")).to eq("done")
  end

  it "lists its tools" do
    mcp("tools/list")

    expect(mcp_result["tools"].pluck("name")).to include("list_projects")
  end

  it "limits the requests per token" do
    allow(Mcp::ServerController.cache_store).to receive(:increment).and_return(1_000)

    mcp("tools/list")

    expect(response).to have_http_status(:too_many_requests)
  end

  it "refuses a foreign Host header" do
    host! "evil.example.com"
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
      headers: { "Authorization" => "Bearer #{secret}", "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }

    expect(response).to have_http_status(:forbidden)
  end

  describe "list_projects" do
    it "lists the projects the token reaches, with the access it gives" do
      archived = create(:project, org:, archived_at: Time.current).tap { create(:participant, project: it, member:) }
      create(:project, org:) # no participation
      elsewhere = create(:project) # another org, no grant
      create(:participant, project: elsewhere, member: create(:member, org: elsewhere.org, user:))

      data = tool_data(call_tool("list_projects"))

      expect(data.map { it.values_at("org", "project", "access", "role") })
        .to contain_exactly([ org.slug, project.slug, "write", "participant" ], [ org.slug, archived.slug, "read", "participant" ])
    end

    it "lists nothing for a token whose grants have no effect" do
      member.participations.destroy_all

      expect(tool_data(call_tool("list_projects"))).to eq([])
    end
  end
end
