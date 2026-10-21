module Users
  # The signed-in user's personal access tokens for the MCP server (#108). Each one is
  #   a TokenAuth::Connection with its grants; the secret is shown once, on create.
  #
  class AccessTokensController < ApplicationController
    # the signed-in user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    def index
      @token_auth_connection = current_user.token_auth_connections.build
    end

    # a full page, not Turbo: it shows the secret instead of redirecting
    def create
      @token_auth_connection = current_user.token_auth_connections.build(name: params.dig(:token_auth_connection, :name))
      grant_params.each { @token_auth_connection.grants.build(it) }
      @expires_in_days = params[:expires_in_days].to_i

      if issuable? && (@secret = save_with_token)
        response.headers["Cache-Control"] = "no-store"
        render :create, status: :created
      else
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      token_auth_connection = current_user.token_auth_connections.personal.find(params[:id])
      token_auth_connection.revoke!

      redirect_to user_access_tokens_path, notice: t("controllers.access_tokens.revoked", name: token_auth_connection.name)
    end

    # personal tokens and connected apps alike
    def destroy_all
      count = current_user.token_auth_connections.revoke_all!

      redirect_to user_access_tokens_path, notice: t("controllers.access_tokens.revoked_all", count:)
    end

    private

    helper_method def personal_token_auth_connections
      current_user.token_auth_connections.personal.active.includes(:access_tokens, grants: %i[ org project ]).order(created_at: :desc)
    end

    # the orgs and projects the user may grant, see token_auth/connections/_grants_fields
    helper_method def grantable_memberships
      @grantable_memberships ||= current_user.memberships.active.includes(:org, participations: :project)
        .sort_by { it.org.name }
        .each_with_object({}) { |member, by_member| by_member[member] = readable_projects(member) }
    end

    def readable_projects(member)
      member.participations.select { ProjectPolicy::READ_ROLES.include?(it.role) }.map(&:project).sort_by(&:name)
    end

    # orgs and projects the user doesn't take part in are dropped
    def grant_params
      grants = params.fetch(:grants, {}).permit(orgs: {}, projects: {})
      memberships = grantable_memberships
      orgs = memberships.keys.map(&:org).index_by(&:id)
      projects = memberships.values.flatten.index_by(&:id)

      chosen(grants[:orgs]).filter_map { |id, access| { org: orgs[id], access: } if orgs[id] } +
        chosen(grants[:projects]).filter_map { |id, access| { org: projects[id].org, project: projects[id], access: } if projects[id] }
    end

    def chosen(accesses)
      accesses.to_h.select { |_id, access| TokenAuth::ConnectionGrant::ACCESS.include?(access) }
    end

    def issuable?
      @token_auth_connection.validate
      @token_auth_connection.errors.add(:grants, :blank) if @token_auth_connection.grants.empty?
      @token_auth_connection.errors.add(:base, :expiry) unless TokenAuth::Connection::PERSONAL_EXPIRY_DAYS.include?(@expires_in_days)
      @token_auth_connection.errors.empty?
    end

    def save_with_token
      TokenAuth::Connection.transaction do
        @token_auth_connection.save!
        @token_auth_connection.create_access_token!(expires_in: @expires_in_days.days)
      end
    end
  end
end
