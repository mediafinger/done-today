module Mcp
  # Projects through an MCP connection: readable where it gives any access, writable
  #   where it gives :write (Connection#access_for). Asked for one Connection, no Member.
  #
  class ProjectPolicy < ActionPolicy::Base
    authorization_targets.delete(:user)
    authorize :connection

    default_rule nil

    relation_scope do |relation|
      relation.where(id: connection.readable_projects.select(:id))
    end

    def read?
      connection.access_for(record).present?
    end

    def write?
      connection.access_for(record) == :write
    end
  end
end
