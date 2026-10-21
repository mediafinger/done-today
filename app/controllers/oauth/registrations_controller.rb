module Oauth
  # RFC 7591 dynamic client registration, so hosted AI apps register themselves (#109).
  #   Public clients only: no secret, PKCE on every authorization. Apps nobody authorizes
  #   within a day are deleted again (TokenAuth::CleanupJob).
  #
  class RegistrationsController < ActionController::API
    GRANT_TYPES = %w[authorization_code refresh_token].freeze
    RESPONSE_TYPES = %w[code].freeze

    # the body belongs to RFC 7591, unwrapped
    wrap_parameters false

    rate_limit to: 10, within: 1.hour, by: -> { request.remote_ip }, with: -> { head :too_many_requests }

    def create
      if (problem = unsupported_metadata)
        return refuse(:invalid_client_metadata, problem)
      end

      application = Doorkeeper::Application.new(name:, redirect_uri: redirect_uris.join("\n"), scopes: scopes.join(" "), confidential: false)
      unless redirect_uris.any? && redirect_uris.none?(/\s/) && application.save
        return refuse(:invalid_redirect_uri, "HTTPS, or http on localhost, without a fragment")
      end

      render status: :created, json: {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        client_name: application.name,
        redirect_uris:,
        grant_types: GRANT_TYPES,
        response_types: RESPONSE_TYPES,
        token_endpoint_auth_method: "none",
        scope: application.scopes.to_s
      }
    end

    private

    def unsupported_metadata
      if (params[:token_endpoint_auth_method].presence || "none") != "none"
        "only public clients: token_endpoint_auth_method none"
      elsif (strings(:grant_types) - GRANT_TYPES).any?
        "grant_types: #{GRANT_TYPES.join(", ")}"
      elsif (strings(:response_types) - RESPONSE_TYPES).any?
        "response_types: #{RESPONSE_TYPES.join(", ")}"
      elsif (scopes - TokenAuth::SCOPES).any?
        "scope: #{TokenAuth::SCOPES.join(" ")}"
      end
    end

    def refuse(error, description)
      render json: { error:, error_description: description }, status: :bad_request
    end

    # the redirect host is what the consent page shows next to it, the name is never trusted alone
    def name
      params[:client_name].to_s.squish.truncate(100).presence || "Unnamed app"
    end

    def redirect_uris = strings(:redirect_uris)

    def scopes
      @scopes ||= params[:scope].present? ? params[:scope].to_s.split : TokenAuth::SCOPES
    end

    def strings(key)
      Array(params[key]).select { it.is_a?(String) }
    end
  end
end
