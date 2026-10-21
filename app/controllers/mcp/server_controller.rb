module Mcp
  # The MCP server for AI clients (#108): Streamable HTTP, stateless, one MCP::Server per
  #   request (the mcp gem's Rails controller pattern). A bearer token authenticates, never
  #   the cookie session; Mcp::TokenVerifier puts its connection into Current.
  #
  class ServerController < ActionController::API
    TOOLS = [ ListProjectsTool, ListEntriesTool, GetDayTool, GetSummaryTool, GetTimeIssuesTool ].freeze

    # the body belongs to the transport, unparsed
    wrap_parameters false

    # by the token, so a client's limit doesn't depend on its IP
    rate_limit to: 120, within: 1.minute, by: -> { Digest::SHA256.hexdigest(request.authorization.to_s) },
      with: -> { head :too_many_requests }

    def handle
      status, headers, body = transport.handle_request(request)

      response.headers.merge!(headers)
      self.status = status
      self.response_body = body
    end

    private

    def transport
      MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        enable_json_response: true,
        serve_subscriptions_listen: false,
        token_verifier: TokenVerifier.new,
        allowed_hosts: [ AppConf.done_host ]
      )
    end

    def server
      MCP::Server.new(
        name: "done",
        title: AppConf.done_name,
        version: "1",
        instructions: "Reads and writes your own entries in done. Call list_projects first for the org and project slugs.",
        tools: TOOLS
      )
    end
  end
end
