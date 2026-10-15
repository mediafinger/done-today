# Where / sends a user: the project they worked in last, as long as they may still
#   read it and it is not archived.
#
#   LandingService.call(user:) # => #<data LandingService::Result org=#<Org …>, project=nil>
#
class LandingService
  Result = Data.define(:org, :project)

  class << self
    def call(user:)
      member = user.memberships.active.find_by(org_id: user.last_org_id)
      project = member && readable_projects(member).find_by(id: user.last_project_id)

      Result.new(org: member&.org, project:)
    end

    private

    def readable_projects(member)
      ProjectPolicy.new(member:).apply_scope(member.org.projects.active, type: :active_record_relation)
    end
  end
end
