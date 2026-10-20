module Mcp
  class ListProjectsTool < BaseTool
    tool_name "list_projects"
    description "The done projects this token reaches, with your role and the access it gives (read or write). " \
      "Other tools take the org and project slugs from here."
    input_schema(properties: {})
    annotations(**Schema::READ_ONLY)

    def run
      projects = authorized_scope(Project.all, with: ProjectPolicy).includes(:org).sort_by { [ it.org.name, it.name ] }
      roles = Participant.where(project: projects, member: Current.user.memberships).pluck(:project_id, :role).to_h

      projects.map do |project|
        {
          org: project.org.slug, org_name: project.org.name,
          project: project.slug, project_name: project.name, archived: project.archived?,
          role: roles[project.id], access: Current.connection.access_for(project)
        }
      end
    end
  end
end
