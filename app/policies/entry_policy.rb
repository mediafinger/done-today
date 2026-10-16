# A participant edits their own entries, a project owner everybody's.
#
class EntryPolicy < ApplicationPolicy
  def self.readable(member)
    Entry.where(day: Day.where(project: ProjectPolicy.readable(member)))
  end

  def self.editable(member)
    return Entry.none unless active?(member)

    owned = member.participations.includes_all_roles(%w[owner]).select(:project_id)
    joined = member.participations.includes_all_roles(%w[participant]).select(:project_id)

    Entry.where(day: Day.where(org_id: member.org_id, project_id: owned))
      .or(Entry.where(member:, day: Day.where(org_id: member.org_id, project_id: joined)))
  end

  def update?
    roles = project_roles(record.day.project)

    roles.include?("owner") || (roles.include?("participant") && record.member_id == member.id)
  end

  def history?
    ProjectPolicy.new(member, record.day.project).entry_history?
  end
end
