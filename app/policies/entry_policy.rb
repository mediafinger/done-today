# A participant edits their own entries, a project lead everybody's. Nobody edits
#   the entries of an archived project.
#
class EntryPolicy < ApplicationPolicy
  relation_scope do |relation|
    relation.where(day: Day.where(project: authorized_scope(Project.all)))
  end

  relation_scope(:editable) do |relation|
    next relation.none unless active?

    led = member.participations.includes_all_roles(%w[lead]).select(:project_id)
    joined = member.participations.includes_all_roles(%w[participant]).select(:project_id)
    days = Day.where.not(project_id: Project.archived.select(:id))

    relation.where(day: days.where(project_id: led))
      .or(relation.where(member:, day: days.where(project_id: joined)))
  end

  def update?
    project = record.day.project
    return false if project.archived?

    roles = project_roles(project)

    roles.include?("lead") || (roles.include?("participant") && record.member_id == member.id)
  end

  def history?
    allowed_to?(:entry_history?, record.day.project)
  end
end
