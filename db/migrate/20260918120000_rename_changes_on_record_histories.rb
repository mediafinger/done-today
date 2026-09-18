# `changes` is defined by ActiveModel::Dirty, so Rails never defines an attribute
# method for a column of that name -- `record.changes` returns the dirty-tracking
# hash and the column is unreachable.
#
# The development database had already been renamed by hand; this migration brings
# the migrations and schema.rb in line with it, and is a no-op where it already ran.
#
class RenameChangesOnRecordHistories < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:record_histories, :record_changes)

    rename_column :record_histories, :changes, :record_changes
  end

  def down
    return if column_exists?(:record_histories, :changes)

    rename_column :record_histories, :record_changes, :changes
  end
end
