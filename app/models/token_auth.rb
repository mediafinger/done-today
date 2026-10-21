# Bearer tokens for the MCP server: personal access tokens (#108) and OAuth apps (#109)
#   share the connections, their grants and Doorkeeper's tokens.
#
module TokenAuth
  # what an OAuth app may ask for; the grants on the consent page decide the orgs and projects
  SCOPES = %w[entries:read entries:write].freeze

  def self.table_name_prefix = "token_auth_"

  # the OAuth issuer, this app's origin
  def self.issuer = AppConf.done_url

  # the MCP server, as clients name it in RFC 8707's resource parameter
  def self.resource = "#{issuer}/mcp"

  # desktop clients receive the authorization code on their own machine, over http
  def self.loopback?(host) = %w[localhost 127.0.0.1 [::1] ::1].include?(host)

  # RFC 9728, also the target of /mcp's 401 challenge
  def self.protected_resource_metadata
    @protected_resource_metadata ||= MCP::Server::OAuth::ProtectedResourceMetadata.new(
      resource:,
      authorization_servers: [ issuer ],
      scopes_supported: SCOPES,
      resource_name: AppConf.done_name,
      resource_documentation: "#{issuer}/help#ai-clients"
    )
  end
end
