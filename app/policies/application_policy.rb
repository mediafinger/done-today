# ActionPolicy policies, one per record type, always asked for one Member (the
#   signed-in user within the org of the path, nil outside of one).
#
#   * the org role lives on `Member#role` (guest, member, manager, owner): all but guests are internal,
#     managers and owners manage the org, only owners touch the owner role
#   * project roles live on `Participant#role` (observer, participant, lead)
#
#   Rules answer "may this member do X to this record?", relation scopes return
#   the records a member may see or change. Pre-checks do not run for scopes.
#
class ApplicationPolicy < ActionPolicy::Base
  # roles depend on the org, so the member is the subject, not the user
  authorization_targets.delete(:user)
  authorize :member, allow_nil: true

  # an unknown rule raises instead of falling back to manage?
  default_rule nil

  pre_check :deny_inactive
  pre_check :deny_other_org

  private

  # an archived member keeps their entries, but no access
  def active?
    member.present? && !member.archived?
  end

  # guests are externals, they only see their own projects
  def internal?
    active? && member.internal?
  end

  def org_manager?
    active? && member.managing?
  end

  def org_owner?
    active? && member.owner?
  end

  def deny_inactive
    deny! unless active?
  end

  # keeps allow_org_manager to the manager's own org
  def deny_other_org
    deny! if record.respond_to?(:org_id) && record.org_id != member.org_id
  end

  def allow_org_manager
    allow! if org_manager?
  end

  # nil when the member does not participate
  def project_role(project)
    @project_roles ||= {}
    return @project_roles[project.id] if @project_roles.key?(project.id)

    @project_roles[project.id] = member.participations.find_by(project:)&.role
  end
end
