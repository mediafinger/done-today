# Where / sends a user: the project they worked in last, as long as they may still
#   read it and it is not archived. Without one remembered, the only org or project there is.
#
#   LandingService.call(user:) # => #<data LandingService::Result org=#<Org …>, project=nil>
#
class LandingService
  include ActionPolicy::Behaviour

  Result = Data.define(:org, :project)

  authorize :member

  def self.call(user:) = new(user).result

  def initialize(user)
    @user = user
  end

  def result
    Result.new(org: member&.org, project: member && project)
  end

  private

  attr_reader :user

  def member
    return @member if defined?(@member)

    members = user.memberships.active
    @member = members.find_by(org_id: user.last_org_id) || only(members)
  end

  def project
    readable_projects.find_by(id: user.last_project_id) || only(joined_projects)
  end

  def readable_projects
    authorized_scope(member.org.projects.active)
  end

  # org managers and owners read every project, but only land in one they take part in
  def joined_projects
    member.org.projects.active.where(id: member.participations.select(:project_id))
  end

  def only(relation)
    records = relation.limit(2).to_a
    records.first if records.one?
  end
end
