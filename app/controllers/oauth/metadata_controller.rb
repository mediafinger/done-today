module Oauth
  # The discovery documents hosted AI apps read before they authorize for /mcp (#109):
  #   RFC 9728 for the resource, RFC 8414 for done as its authorization server.
  #   Public, without a session, readable by browser-based clients.
  #
  class MetadataController < ActionController::API
    before_action { response.headers.merge!("Access-Control-Allow-Origin" => "*", "Cache-Control" => "public, max-age=3600") }

    def protected_resource
      render json: TokenAuth.protected_resource_metadata
    end

    def authorization_server
      render json: {
        issuer: TokenAuth.issuer,
        authorization_endpoint: url("/oauth/authorize"), # the consent page follows with #109
        token_endpoint: url(oauth_token_path),
        revocation_endpoint: url(oauth_revoke_path),
        response_types_supported: %w[code],
        grant_types_supported: %w[authorization_code refresh_token],
        code_challenge_methods_supported: %w[S256],
        # public clients prove themselves with PKCE, they have no secret
        token_endpoint_auth_methods_supported: %w[none],
        revocation_endpoint_auth_methods_supported: %w[none],
        scopes_supported: TokenAuth::SCOPES,
        service_documentation: "#{TokenAuth.issuer}/help#ai-clients"
      }
    end

    private

    def url(path) = "#{TokenAuth.issuer}#{path}"
  end
end
