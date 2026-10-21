module Mcp
  class UpdateEntryTool < BaseTool
    tool_name "update_entry"
    description "Changes the log and/or the status of an entry of yours. Pass the updated_at you read: " \
      "if the entry changed since, nothing is written and you get a conflict to read it again. " \
      "Past days are locked: pass unlocked: true only when the user asked to change that day. #{Schema::MARKUP}"
    input_schema(
      properties: {
        id: { type: "string", description: "The entry's id, from list_entries or get_day" },
        updated_at: { type: "string", description: "The entry's updated_at as read" },
        log: { type: "string", minLength: 3, maxLength: 500 },
        status: { type: "string", enum: Entry::STATES },
        unlocked: { type: "boolean", description: "Write into a past day" }
      },
      required: %w[id updated_at]
    )
    annotations(**Schema::WRITE)

    def run(id:, updated_at:, log: nil, status: nil, unlocked: false)
      entry = authorized_scope(Entry.all, with: EntryPolicy).find(id)
      authorize!(entry, to: :update?, with: EntryPolicy)

      Current.org = entry.org
      Current.member = entry.member

      entry.with_lock do
        raise Error, "conflict: the entry changed since, read it again" unless entry.updated_at.iso8601(6) == updated_at

        saved_data(Entries::Update.call(entry:, attributes: { log:, status: }.compact, unlocked:))
      end
    end
  end
end
