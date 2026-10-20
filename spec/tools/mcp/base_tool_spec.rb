require "rails_helper"

# Like authorization_verified_spec for the routes: every tool of the MCP server runs
#   with arguments that reach its end, so BaseTool's check that it authorized runs too.
#   A new tool needs its arguments below, or this fails.
#
RSpec.describe Mcp::BaseTool do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:connection) { create(:connection, user: member.user) }

  before do
    create(:participant, project:, member:)
    create(:connection_grant, connection:, org:, access: "write")
    Current.connection = connection
    Current.user = member.user
  end

  def slugs = { org: org.slug, project: project.slug }

  def arguments(tool)
    case tool.tool_name
    when "list_projects" then {}
    when "list_entries" then slugs
    when "get_day" then slugs.merge(date: Date.current.iso8601)
    when "get_summary", "get_time_issues", "export_entries" then slugs.merge(month: "2026-03")
    when "create_entry" then slugs.merge(log: "Wrote a spec")
    when "update_entry"
      entry = create(:entry, day: create(:day, project:), member:)
      { id: entry.id, updated_at: entry.updated_at.iso8601(6), status: "done" }
    end
  end

  Mcp::ServerController::TOOLS.each do |tool|
    it "runs #{tool.tool_name} authorized" do
      args = arguments(tool)
      expect(args).not_to be_nil, "add the arguments of #{tool.tool_name}"

      response = tool.call(**JSON.parse(args.to_json, symbolize_names: true), server_context: nil)

      expect(response).not_to be_error
    end
  end

  it "raises for a tool that neither authorizes nor scopes" do
    tool = Class.new(Mcp::BaseTool) do
      def run = []
    end

    expect { tool.call(server_context: nil) }.to raise_error(Mcp::BaseTool::NotAuthorized)
  end

  it "answers a refusal as a tool error" do
    elsewhere = create(:project)
    tool = Class.new(Mcp::BaseTool) do
      define_method(:run) { authorize!(elsewhere, to: :write?, with: Mcp::ProjectPolicy) }
    end

    expect(tool.call(server_context: nil)).to be_error
  end
end
