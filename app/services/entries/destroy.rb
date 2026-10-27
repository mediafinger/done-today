module Entries
  # Deletes an entry. The day stays, and the :deleted history keeps the last log and status.
  #
  #   Entries::Destroy.call(entry:) # => #<data Entries::Result entry=#<Entry …>, saved=true>
  #
  class Destroy
    def self.call(entry:, unlocked: false)
      saved = Entries.open_day?(entry, unlocked:) && entry.destroy_with_history.present?

      Result.new(entry:, saved:)
    end
  end
end
