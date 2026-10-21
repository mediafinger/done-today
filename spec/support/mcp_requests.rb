# JSON-RPC calls to /mcp with a bearer token, as an MCP client sends them.
module McpRequests
  def mcp(method, params = {}, token: secret)
    headers = { "Accept" => "application/json, text/event-stream", "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    host! AppConf.done_host
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method:, params: }.to_json, headers:
  end

  def call_tool(name, **arguments)
    mcp("tools/call", { name:, arguments: })
    mcp_result
  end

  def mcp_result
    JSON.parse(response.body).fetch("result") { raise "no result: #{response.body}" }
  end

  # the JSON a tool answered with
  def tool_data(result = mcp_result)
    JSON.parse(result.dig("content", 0, "text"))
  end

  # a personal access token of the user, with the grants given as { org or project => access }
  def personal_token(user, grants)
    connection = create(:token_auth_connection, user:)
    grants.each do |target, access|
      org, project = target.is_a?(Project) ? [ target.org, target ] : [ target, nil ]
      create(:token_auth_connection_grant, connection:, org:, project:, access:)
    end
    connection.create_access_token!(expires_in: 1.day)
  end
end

RSpec.configure { |config| config.include McpRequests, type: :request }
