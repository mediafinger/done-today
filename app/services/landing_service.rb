# Where / sends a user: the project they worked in last, as long as they may still
#   read it and it is not archived. Without one remembered, the only org or project there is.
#
#   LandingService.call(user:) # => #<data LandingService::Result org=#<Org …>, project=nil>
#
class LandingService
  Result = Data.define(:org, :project)

  class << self
    def call(user:)
      members = user.memberships.active
      member = members.find_by(org_id: user.last_org_id) || only(members)
      project = member && (readable_projects(member).find_by(id: user.last_project_id) || only(joined_projects(member)))

      Result.new(org: member&.org, project:)
    end

    private

    def readable_projects(member)
      ProjectPolicy.new(member:).apply_scope(member.org.projects.active, type: :active_record_relation)
    end

    # org managers and owners read every project, but only land in one they take part in
    def joined_projects(member)
      member.org.projects.active.where(id: member.participations.select(:project_id))
    end

    def only(relation)
      records = relation.limit(2).to_a
      records.first if records.one?
    end
  end
end
