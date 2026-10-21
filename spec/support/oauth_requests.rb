# The OAuth flow as a hosted AI app runs it: a registered public client with PKCE (#109).
module OauthRequests
  OAUTH_REDIRECT_URI = "https://ai.example/oauth/callback".freeze
  OAUTH_VERIFIER = "a-code-verifier-long-enough-for-rfc-7636-of-at-least-43-chars".freeze

  def oauth_app(scopes: TokenAuth::SCOPES.join(" "))
    Doorkeeper::Application.create!(name: "AI app", redirect_uri: OAUTH_REDIRECT_URI, scopes:, confidential: false)
  end

  def oauth_authorize_params(app, **overrides)
    {
      client_id: app.uid, redirect_uri: OAUTH_REDIRECT_URI, response_type: "code", state: "s1",
      scope: app.scopes.to_s, resource: TokenAuth.resource,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(OAUTH_VERIFIER), padding: false),
      code_challenge_method: "S256"
    }.merge(overrides).compact
  end

  # the code from the redirect back to the app, after the user approved
  def oauth_code
    Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
  end

  def oauth_exchange(app, code)
    post "/oauth/token", params: {
      grant_type: "authorization_code", client_id: app.uid, code:, redirect_uri: OAUTH_REDIRECT_URI,
      code_verifier: OAUTH_VERIFIER, resource: TokenAuth.resource
    }
    response.parsed_body
  end
end

RSpec.configure { |config| config.include OauthRequests, type: :request }
