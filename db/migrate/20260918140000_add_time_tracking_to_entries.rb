# Everything the time-tracking features need is derived from `entries.log`; these
# columns are the parsed projection of that text, written by `EntryLog` on save.
# `log` stays the single source of truth, the columns exist so tags and durations
# are queryable in SQL.
#
class AddTimeTrackingToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :tags,              :text, array: true, default: [], null: false
    add_column :entries, :day_start_minutes, :integer   # from  start@09:00
    add_column :entries, :day_end_minutes,   :integer   # from  end@18:00
    add_column :entries, :from_minutes,      :integer   # from  from@11:00
    add_column :entries, :to_minutes,        :integer   # from  to@12:00
    add_column :entries, :duration_minutes,  :integer   # from  for~1h30m, or to - from

    add_index :entries, :tags, using: :gin
    add_index :entries, [ :day_id, :from_minutes ]

    # The composite index above starts with day_id, so it already serves every
    # lookup the single-column index served -- keeping both only costs writes.
    remove_index :entries, :day_id
  end
end
