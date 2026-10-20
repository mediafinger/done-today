module Mcp
  class ListEntriesTool < BaseTool
    LIMIT = 50
    MAX_LIMIT = 200

    tool_name "list_entries"
    description "Your own entries in one project, newest first, with what the log's markup says " \
      "(tags, day start and end, from/to, duration). #{Schema::UNTRUSTED}"
    input_schema(
      properties: Schema::PROJECT.merge(
        from: { type: "string", description: "First date, e.g. 2026-03-01" },
        to: { type: "string", description: "Last date, e.g. 2026-03-31" },
        tag: { type: "string", description: "Only entries with this tag, without the #" },
        status: { type: "string", enum: Entry::STATES },
        limit: { type: "integer", minimum: 1, maximum: MAX_LIMIT, description: "Entries per page, #{LIMIT} by default" },
        cursor: { type: "string", description: "next_cursor of the previous page" }
      ),
      required: %w[org project]
    )
    annotations(**Schema::READ_ONLY)

    def run(org:, project:, from: nil, to: nil, tag: nil, status: nil, limit: LIMIT, cursor: nil)
      entries = own_entries(find_project(org, project)).includes(:day)
      entries = entries.where(days: { date: date(from, "from").. }) if from
      entries = entries.where(days: { date: ..date(to, "to") }) if to
      entries = entries.tagged(tag) if tag
      entries = entries.where(status:) if status

      limit = limit.to_i.clamp(1, MAX_LIMIT)
      offset = cursor.to_i
      page = entries.order("days.date DESC", created_at: :desc, id: :desc).offset(offset).limit(limit + 1).to_a

      { entries: page.first(limit).map { entry_data(it) }, next_cursor: ((offset + limit).to_s if page.size > limit) }
    end
  end
end
