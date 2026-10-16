# A participant edits their own entries, a project owner everybody's. Nobody edits
#   the entries of an archived project.
#
class EntryPolicy < ApplicationPolicy
  def self.readable(member)
    Entry.where(day: Day.where(project: ProjectPolicy.readable(member)))
  end

  def self.editable(member)
    return Entry.none unless active?(member)

    owned = member.participations.includes_all_roles(%w[owner]).select(:project_id)
    joined = member.participations.includes_all_roles(%w[participant]).select(:project_id)

    days = Day.where(org_id: member.org_id).where.not(project_id: Project.archived.select(:id))

    Entry.where(day: days.where(project_id: owned))
      .or(Entry.where(member:, day: days.where(project_id: joined)))
  end

  def update?
    project = record.day.project
    return false if project.archived?

    roles = project_roles(project)

    roles.include?("owner") || (roles.include?("participant") && record.member_id == member.id)
  end
end
