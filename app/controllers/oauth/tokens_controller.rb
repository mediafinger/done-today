module Oauth
  # Doorkeeper's token endpoint. A refresh is refused once its connection is revoked or
  #   no grant gives access any more, and after 30 days: the app has to ask the user again.
  #
  class TokensController < Doorkeeper::TokensController
    REFRESH_TOKEN_LIFETIME = 30.days

    before_action :refuse_stale_refresh, only: :create, if: -> { params[:grant_type] == "refresh_token" }

    private

    def refuse_stale_refresh
      token = Doorkeeper::AccessToken.by_refresh_token(params[:refresh_token].to_s)
      return unless token # Doorkeeper answers unknown ones

      connection = TokenAuth::Connection.find_by(id: token.connection_id)
      return if connection&.refreshable? && token.created_at > REFRESH_TOKEN_LIFETIME.ago

      render json: { error: "invalid_grant", error_description: "Connect the app in done again" }, status: :bad_request
    end
  end
end
