require "rails_helper"

# RFC 7591 dynamic client registration: hosted AI apps register themselves (#109)
RSpec.describe "OAuth client registration" do
  def register(metadata)
    post "/oauth/register", params: metadata.to_json, headers: { "Content-Type" => "application/json" }
  end

  let(:redirect_uri) { "https://ai.example/oauth/callback" }

  it "registers a public client and answers with its metadata" do
    register(client_name: "AI app", redirect_uris: [ redirect_uri ])

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      "client_name" => "AI app",
      "redirect_uris" => [ redirect_uri ],
      "token_endpoint_auth_method" => "none",
      "grant_types" => %w[authorization_code refresh_token],
      "response_types" => [ "code" ]
    )
    expect(response.parsed_body).not_to have_key("client_secret")

    application = Doorkeeper::Application.find_by!(uid: response.parsed_body["client_id"])
    expect(application).to have_attributes(confidential: false, name: "AI app")
  end

  it "accepts several redirect URIs, and loopback ones over http for desktop clients" do
    uris = [ redirect_uri, "http://localhost:6274/callback", "http://127.0.0.1:33418/callback" ]

    register(client_name: "Desktop app", redirect_uris: uris)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["redirect_uris"]).to eq(uris)
  end

  it "keeps the requested scopes, all of them without a request" do
    register(redirect_uris: [ redirect_uri ], scope: "entries:read")
    expect(response.parsed_body["scope"]).to eq("entries:read")

    register(redirect_uris: [ redirect_uri ])
    expect(response.parsed_body["scope"]).to eq(TokenAuth::SCOPES.join(" "))
  end

  it "names an app without a name" do
    register(redirect_uris: [ redirect_uri ])

    expect(response.parsed_body["client_name"]).to be_present
  end

  {
    "plain http" => "http://ai.example/callback",
    "a custom scheme" => "cursor://oauth/callback",
    "a fragment" => "https://ai.example/callback#done",
    "a relative path" => "/callback",
    "a script" => "javascript:alert(1)"
  }.each do |reason, uri|
    it "refuses a redirect URI with #{reason}" do
      expect { register(redirect_uris: [ uri ]) }.not_to change(Doorkeeper::Application, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_redirect_uri")
    end
  end

  it "refuses a client without redirect URIs" do
    register(client_name: "AI app")

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to eq("invalid_redirect_uri")
  end

  it "refuses clients that want a secret" do
    register(redirect_uris: [ redirect_uri ], token_endpoint_auth_method: "client_secret_basic")

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to eq("invalid_client_metadata")
  end

  it "refuses unknown scopes and other flows" do
    register(redirect_uris: [ redirect_uri ], scope: "entries:read admin")
    expect(response.parsed_body["error"]).to eq("invalid_client_metadata")

    register(redirect_uris: [ redirect_uri ], grant_types: %w[client_credentials])
    expect(response.parsed_body["error"]).to eq("invalid_client_metadata")
  end

  it "limits registrations per IP" do
    allow(Oauth::RegistrationsController.cache_store).to receive(:increment).and_return(1_000)

    register(redirect_uris: [ redirect_uri ])

    expect(response).to have_http_status(:too_many_requests)
  end

  it "is listed in the authorization server metadata" do
    get "/.well-known/oauth-authorization-server"

    expect(response.parsed_body["registration_endpoint"]).to eq("#{AppConf.done_url}/oauth/register")
  end
end
