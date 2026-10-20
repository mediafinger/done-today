# Writes of a member's entries, shared by the entry form and the MCP tools. Authorization
#   stays with the caller. The history is written by Current.user, so set it outside requests.
#
module Entries
  Result = Data.define(:entry, :saved)

  # The lock on past days guards against changing them in passing. Whoever may write
  #   can lift it with `unlocked`, like the unlocked day page does.
  #
  def self.open_day?(entry, unlocked:)
    return true unless entry.day.date&.past? && !unlocked

    entry.errors.add(:base, :day_locked, date: entry.day.date.iso8601)
    false
  end
end
