require "rails_helper"

# How hosted AI apps find out where to authorize for /mcp (#109)
RSpec.describe "OAuth discovery" do
  let(:origin) { AppConf.done_url }

  def path_of(url)
    url.delete_prefix(origin)
  end

  def routed?(verb, url)
    Rails.application.routes.recognize_path(path_of(url), method: verb).present?
  rescue ActionController::RoutingError
    false
  end

  describe "GET /.well-known/oauth-protected-resource/mcp (RFC 9728)" do
    it "names /mcp as the resource and done as its authorization server" do
      get "/.well-known/oauth-protected-resource/mcp"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "resource" => "#{origin}/mcp",
        "authorization_servers" => [ origin ],
        "scopes_supported" => TokenAuth::SCOPES,
        "bearer_methods_supported" => [ "header" ]
      )
    end

    it "can be read by browser-based clients and needs no session" do
      get "/.well-known/oauth-protected-resource/mcp"

      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.cookies).to be_empty
    end
  end

  describe "GET /.well-known/oauth-authorization-server (RFC 8414)" do
    subject(:metadata) { response.parsed_body }

    before { get "/.well-known/oauth-authorization-server" }

    it "describes the authorization code flow with PKCE for public clients" do
      expect(response).to have_http_status(:ok)
      expect(metadata).to include(
        "issuer" => origin,
        "response_types_supported" => [ "code" ],
        "grant_types_supported" => %w[authorization_code refresh_token],
        "code_challenge_methods_supported" => [ "S256" ],
        "token_endpoint_auth_methods_supported" => [ "none" ],
        "scopes_supported" => TokenAuth::SCOPES
      )
    end

    it "points at endpoints of this app" do
      expect(metadata["token_endpoint"]).to start_with(origin)
      expect(routed?(:post, metadata["token_endpoint"])).to be(true)
      expect(routed?(:post, metadata["revocation_endpoint"])).to be(true)
      expect(metadata["authorization_endpoint"]).to eq("#{origin}/oauth/authorize")
    end

    it "can be read by browser-based clients" do
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end
  end
end
