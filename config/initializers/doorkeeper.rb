# Stores the MCP server's access tokens (#108) and will issue them over OAuth (#109).
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
end
