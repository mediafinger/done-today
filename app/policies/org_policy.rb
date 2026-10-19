# The org's own pages beyond members and projects. Ask with the member's org.
#
class OrgPolicy < ApplicationPolicy
  pre_check :deny_foreign_org

  # every project's tag times, everyone's
  def tag_times?
    org_manager?
  end

  private

  # an Org has no org_id for ApplicationPolicy#deny_other_org
  def deny_foreign_org
    deny! if record.id != member.org_id
  end
end
