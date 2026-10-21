# Stores the MCP server's access tokens (#108) and issues them over OAuth (#109).
#   Every token belongs to a TokenAuth::Connection; personal access tokens have no application.
#
Doorkeeper.configure do
  orm :active_record

  # only SHA-256 digests are stored, the secret is shown once
  hash_token_secrets
  hash_application_secrets

  access_token_generator "TokenAuth::TokenGenerator"

  # a refreshed token keeps its connection
  custom_access_token_attributes [ :connection_id ]

  # OAuth 2.1 for public clients: the authorization code with PKCE (S256 only), rotating refresh tokens
  grant_flows %w[authorization_code]
  force_pkce
  pkce_code_challenge_methods %w[S256]
  use_refresh_token
  access_token_expires_in 1.hour

  # an upper bound, the grants on the consent page decide the orgs and projects
  default_scopes :"entries:read"
  optional_scopes :"entries:write"
  enforce_configured_scopes

  # no other client may read about tokens
  allow_token_introspection false

  # redirect URIs: https, or http on the loopback for desktop clients; no other scheme
  force_ssl_in_redirect_uri { |uri| !TokenAuth.loopback?(uri.host) }
  forbid_redirect_uri { |uri| %w[http https].exclude?(uri.scheme) }
end
