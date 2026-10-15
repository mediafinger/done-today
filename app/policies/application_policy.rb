# Plain Ruby authorization, one policy per record type, always asked for one Member
#   (the signed-in user within the current org).
#
#   * org roles live on `Member#roles` (member, owner)
#   * project roles live on `Participant#roles` (observer, participant, owner)
#
#   Instance predicates answer "may this member do X to this record?".
#   Class methods return the records a member may see or change, as relations.
#
class ApplicationPolicy
  class NotAuthorizedError < StandardError; end

  attr_reader :member, :record

  def initialize(member, record)
    @member = member
    @record = record
  end

  # an archived member keeps their entries, but no access
  def self.active?(member)
    member.present? && !member.archived? && member.roles.intersect?(Member::VALID_ROLES)
  end

  def self.org_owner?(member)
    active?(member) && member.roles.include?("owner")
  end

  # Returns the record, so it can be used inline: `entry = authorize!(:update?)`
  def authorize!(query)
    return record if public_send(query)

    raise NotAuthorizedError, "#{self.class.name}##{query}"
  end

  private

  def org_owner_of?(project)
    self.class.org_owner?(member) && project.org_id == member.org_id
  end

  # [] when the member does not participate or belongs to another org
  def project_roles(project)
    return [] unless self.class.active?(member) && project&.org_id == member.org_id

    @project_roles ||= {}
    @project_roles[project.id] ||= member.participations.find_by(project:)&.roles || []
  end
end
