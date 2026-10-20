module Mcp
  class CreateEntryTool < BaseTool
    # how long a client's retry with the same key gets the first answer
    IDEMPOTENCY = 24.hours

    tool_name "create_entry"
    description "Adds an entry of yours to a day of a project, like typing it into the day page. " \
      "Past days are locked: pass unlocked: true only when the user asked to change that day. #{Schema::MARKUP}"
    input_schema(
      properties: Schema::PROJECT.merge(
        log: { type: "string", minLength: 3, maxLength: 500, description: "The entry as the user would type it" },
        date: { type: "string", description: "The day, e.g. 2026-03-31 (the default: today)" },
        status: { type: "string", enum: Entry::STATES, description: "todo by default" },
        unlocked: { type: "boolean", description: "Write into a past day" },
        idempotency_key: { type: "string", description: "Retrying with the same key returns the first entry instead of a second one" }
      ),
      required: %w[org project log]
    )
    annotations(**Schema::WRITE)

    def run(org:, project:, log:, date: nil, status: nil, unlocked: false, idempotency_key: nil)
      project = find_project(org, project)
      authorize!(project, to: :write?, with: ProjectPolicy)

      key = "mcp/create_entry/#{Current.connection.id}/#{idempotency_key}" if idempotency_key
      cached = Rails.cache.read(key) if key
      return cached if cached

      result = Entries::Create.call(
        project:, member: Current.member, date: date ? date(date, "date") : Time.zone.today, log:, status:, unlocked:
      )

      saved_data(result).tap { Rails.cache.write(key, it, expires_in: IDEMPOTENCY) if key }
    end
  end
end
