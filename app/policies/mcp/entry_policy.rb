module Mcp
  # Entries through an MCP connection: the user's own, in the projects it reaches. No
  #   role lets a token read or change someone else's entries, not even an owner's.
  #
  class EntryPolicy < ActionPolicy::Base
    authorization_targets.delete(:user)
    authorize :connection

    default_rule nil

    relation_scope do |relation|
      relation
        .where(member_id: connection.user.memberships.active.select(:id))
        .where(day_id: Day.where(project_id: connection.readable_projects.select(:id)).select(:id))
    end

    # an own entry, in a project the connection writes
    def update?
      connection.user.memberships.active.exists?(id: record.member_id) && connection.access_for(record.project) == :write
    end
  end
end
