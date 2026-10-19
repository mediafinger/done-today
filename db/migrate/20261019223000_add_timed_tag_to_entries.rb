# The tag a line's duration counts for in reports (EntryLog#timed_tag), filled on
# save like the other parsed columns. Existing entries get it from
# `rake time_tracking:backfill`.
#
class AddTimedTagToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :timed_tag, :string

    # the tag times report sums the entries of a project's days, grouped by tag
    add_index :entries, [ :day_id, :timed_tag ], where: "timed_tag IS NOT NULL"
  end
end
