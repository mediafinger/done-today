# The grants a user picks for a TokenAuth::Connection: on the access tokens page and on
#   the OAuth consent page. Fields in token_auth/connections/_grants_fields.
#
module ConnectionGrantsForm
  extend ActiveSupport::Concern

  included do
    helper_method :grantable_memberships
  end

  private

  # the orgs and projects the user may grant
  def grantable_memberships
    @grantable_memberships ||= current_user.memberships.active.includes(:org, participations: :project)
      .sort_by { it.org.name }
      .each_with_object({}) { |member, by_member| by_member[member] = grantable_projects(member) }
  end

  # the chosen grants as attributes, orgs and projects the user doesn't take part in are
  #   dropped; `accesses` caps them, e.g. at read for an app that asked for no more
  #
  def connection_grant_params(accesses = TokenAuth::ConnectionGrant::ACCESS)
    grants = params.fetch(:grants, {}).permit(orgs: {}, projects: {})
    orgs = grantable_memberships.keys.map(&:org).index_by(&:id)
    projects = grantable_memberships.values.flatten.index_by(&:id)

    chosen(grants[:orgs], accesses).filter_map { |id, access| { org: orgs[id], access: } if orgs[id] } +
      chosen(grants[:projects], accesses).filter_map { |id, access| { org: projects[id].org, project: projects[id], access: } if projects[id] }
  end

  def grantable_projects(member)
    member.participations.select { ProjectPolicy::READ_ROLES.include?(it.role) }.map(&:project).sort_by(&:name)
  end

  def chosen(grants, accesses)
    grants.to_h.filter_map do |id, access|
      next unless TokenAuth::ConnectionGrant::ACCESS.include?(access)

      [ id, accesses.include?(access) ? access : accesses.first ]
    end
  end
end
