module Mcp
  # Every tool of the MCP server runs as an instance: `run` returns JSON-able data, with
  #   ActionPolicy on behalf of Current.connection. Like verify_authorized, a tool that
  #   neither authorizes nor scopes raises. Refusals and unknown records are tool errors.
  #
  class BaseTool < MCP::Tool
    include ActionPolicy::Behaviour

    # a refusal the client should read, e.g. a locked past day
    class Error < StandardError; end
    class NotAuthorized < StandardError; end

    authorize :connection, through: :current_connection

    def self.call(server_context:, **arguments)
      Time.use_zone(Current.user.time_zone || Time.zone_default) do
        MCP::Tool::Response.new([ { type: "text", text: JSON.generate(new(**arguments).perform) } ])
      end
    rescue Error, ActionPolicy::Unauthorized, ActiveRecord::RecordNotFound => e
      MCP::Tool::Response.new([ { type: "text", text: error_message(e) } ], error: true)
    end

    def self.error_message(error)
      case error
      when ActionPolicy::Unauthorized then "This token may not do that."
      when ActiveRecord::RecordNotFound then "Not found among the projects and entries this token reaches."
      else error.message
      end
    end

    def initialize(**arguments)
      @arguments = arguments
    end

    def perform
      run(**@arguments).tap { raise NotAuthorized, "#{self.class.name} neither authorized nor scoped" unless @authorized }
    end

    def authorize!(...)
      super.tap { @authorized = true }
    end

    def authorized_scope(...)
      super.tap { @authorized = true }
    end

    private

    def current_connection
      Current.connection
    end
  end
end
