# Bearer tokens for the MCP server: personal access tokens (#108) and OAuth apps (#109)
#   share the connections, their grants and Doorkeeper's tokens.
#
module TokenAuth
  def self.table_name_prefix = "token_auth_"
end
