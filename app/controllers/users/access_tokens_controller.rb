module Users
  # The signed-in user's personal access tokens for the MCP server (#108). Each one is
  #   a Connection with its grants; the secret is shown once, on create.
  #
  class AccessTokensController < ApplicationController
    # the signed-in user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    def index
      @connection = current_user.connections.build
    end

    # a full page, not Turbo: it shows the secret instead of redirecting
    def create
      @connection = current_user.connections.build(name: params.dig(:connection, :name))
      grant_params.each { @connection.grants.build(it) }
      @expires_in_days = params[:expires_in_days].to_i

      if issuable? && (@secret = save_with_token)
        response.headers["Cache-Control"] = "no-store"
        render :create, status: :created
      else
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      connection = current_user.connections.personal.find(params[:id])
      connection.revoke!

      redirect_to user_access_tokens_path, notice: t("controllers.access_tokens.revoked", name: connection.name)
    end

    # personal tokens and connected apps alike
    def destroy_all
      count = current_user.connections.revoke_all!

      redirect_to user_access_tokens_path, notice: t("controllers.access_tokens.revoked_all", count:)
    end

    private

    helper_method def personal_connections
      current_user.connections.personal.active.includes(:access_tokens, grants: %i[ org project ]).order(created_at: :desc)
    end

    # the orgs and projects the user may grant, see connections/_grants_fields
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
      accesses.to_h.select { |_id, access| ConnectionGrant::ACCESS.include?(access) }
    end

    def issuable?
      @connection.validate
      @connection.errors.add(:grants, :blank) if @connection.grants.empty?
      @connection.errors.add(:base, :expiry) unless Connection::PERSONAL_EXPIRY_DAYS.include?(@expires_in_days)
      @connection.errors.empty?
    end

    def save_with_token
      Connection.transaction do
        @connection.save!
        @connection.create_access_token!(expires_in: @expires_in_days.days)
      end
    end
  end
end
