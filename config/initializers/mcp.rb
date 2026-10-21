# Errors inside the MCP server reach the client as a generic "Internal error", the
#   exception goes to Rails' error reporter (and to stderr in tests, the SDK swallows it).
#
MCP.configure do |config|
  config.exception_reporter = lambda do |exception, context|
    warn exception.full_message if Rails.env.test?

    Rails.error.report(exception, handled: true, context: { mcp: context.except(:request) })
  end
end
