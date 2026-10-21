module Mcp
  # The mcp gem's token_verifier: a bearer secret in, its connection into Current (like
  #   Authentication does for the cookie session). Anything else is a 401.
  #
  class TokenVerifier
    def verify(token)
      connection = TokenAuth::Connection.authenticate(token)
      raise MCP::Server::OAuth::InvalidTokenError, "unknown, expired or revoked token" unless connection

      Current.connection = connection
      Current.user = connection.user

      MCP::Server::OAuth::AccessToken.new(
        token:,
        client_id: connection.oauth_application&.uid || "personal",
        subject: connection.user_id,
        claims: { connection_id: connection.id }
      )
    end
  end
end
