module Entries
  # Changes the log and/or status of an entry. Only the keys present are assigned:
  #   a blank log has to reach the validations rather than being dropped.
  #
  #   Entries::Update.call(entry:, attributes: { status: "done" }) # => #<data Entries::Result …>
  #
  class Update
    ATTRIBUTES = %w[log status].freeze

    def self.call(entry:, attributes:, unlocked: false)
      entry.assign_attributes(attributes.to_h.stringify_keys.slice(*ATTRIBUTES))

      saved = Entries.open_day?(entry, unlocked:) && entry.update_with_history

      Result.new(entry:, saved:)
    end
  end
end
