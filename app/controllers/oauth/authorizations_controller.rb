module Oauth
  # Doorkeeper's authorization endpoint with done's consent page (#109): the signed-in user
  #   picks the orgs and projects a hosted AI app reaches. Approving creates the
  #   TokenAuth::Connection with its grants, the access grant and every token issued from
  #   it point to that connection.
  #
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ConnectionGrantsForm

    # the user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    # a page that grants access must never be framed
    content_security_policy { |policy| policy.frame_ancestors :none }

    # the connection is ours to name, never the client's
    prepend_before_action { params.delete(:connection_id) }
    before_action :refuse_other_resource, only: %i[ new create ]

    def create
      @connection_id = SecureRandom.uuid
      return super unless pre_auth.authorizable?

      @token_auth_connection = current_user.token_auth_connections.build(id: @connection_id, oauth_application:, name: oauth_application.name)
      connection_grant_params(grantable_accesses).each { @token_auth_connection.grants.build(it) }
      return render(:new, status: :unprocessable_content) unless issuable?

      TokenAuth::Connection.transaction do
        current_user.token_auth_connections.active.where(oauth_application:).find_each(&:revoke!)
        @token_auth_connection.save!
        super
      end
    end

    private

    helper_method def oauth_application = pre_auth.client.application

    # write only when the app asked for entries:write
    helper_method def grantable_accesses
      pre_auth.scopes.include?("entries:write") ? TokenAuth::ConnectionGrant::ACCESS : %w[read]
    end

    # Doorkeeper hands this to the access grant, and from there to every token (custom_access_token_attributes)
    def pre_auth_params
      super.merge(connection_id: @connection_id).compact
    end

    def issuable?
      @token_auth_connection.validate
      @token_auth_connection.errors.add(:grants, :blank) if @token_auth_connection.grants.empty?
      @token_auth_connection.errors.empty?
    end

    # RFC 8707: done issues tokens for its MCP server only
    def refuse_other_resource
      return if params[:resource].blank? || params[:resource].to_s.chomp("/") == TokenAuth.resource

      render plain: "invalid_target: tokens are issued for #{TokenAuth.resource} only", status: :bad_request
    end
  end
end
