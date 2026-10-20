module Mcp
  # SyntaxGuide as the text of the done://syntax resource: what the help page shows.
  module SyntaxResource
    def self.resource
      MCP::Resource.new(
        uri: Schema::SYNTAX_URI, name: "syntax", title: "Writing entries in done",
        description: "The markup done reads from a log: tags, working time, breaks, tag times", mime_type: "text/markdown"
      )
    end

    def self.text
      [
        "# Writing entries in done",
        "Markup anywhere in a log is optional, the text is saved as typed. " \
          "Working time is start@ to end@ minus the #break durations: #{SyntaxGuide::DAY.join(', ')} adds up to #{SyntaxGuide::DAY_TOTAL}. " \
          "A for~ or from@/to@ duration counts for the one #tag on its line, for reports only.",
        "## Markup",
        *SyntaxGuide::EXAMPLES.map { "- `#{it.log}`: #{it.meaning}" },
        "## Plain text",
        *SyntaxGuide::NOT_MARKUP.map { "- `#{it.log}`: #{it.meaning}" }
      ].join("\n\n")
    end
  end
end
