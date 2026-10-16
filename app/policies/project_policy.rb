# Reading a project means reading all of its entries. An archived project stays
#   readable and exportable, nobody writes into it any more.
#
class ProjectPolicy < ApplicationPolicy
  READ_ROLES = %w[observer participant owner].freeze
  WRITE_ROLES = %w[participant owner].freeze

  def self.readable(member)
    return Project.none unless active?(member)
    return member.org.projects if org_owner?(member)

    member.org.projects.where(id: member.participations.includes_a_role_of(READ_ROLES).select(:project_id))
  end

  # owners of the org or of the project
  def self.manageable(member)
    return Project.none unless active?(member)
    return member.org.projects if org_owner?(member)

    member.org.projects.where(id: member.participations.includes_all_roles(%w[owner]).select(:project_id))
  end

  # a full export covers everybody's entries, so it takes ownership of the org or the project
  def self.exportable(member)
    manageable(member)
  end

  # ask with the Project class: `policy(Project).create?`
  def create?
    self.class.org_owner?(member)
  end

  def show?
    org_owner_of?(record) || roles.intersect?(READ_ROLES)
  end

  # org owners have to join a project to log time in it
  def create_entry?
    !record.archived? && roles.intersect?(WRITE_ROLES)
  end

  def export?
    org_owner_of?(record) || roles.include?("owner")
  end

  # rename, archive, unarchive
  def manage?
    org_owner_of?(record) || roles.include?("owner")
  end

  private

  def roles
    project_roles(record)
  end
end
