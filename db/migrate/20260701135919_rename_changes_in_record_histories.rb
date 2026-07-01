class RenameChangesInRecordHistories < ActiveRecord::Migration[8.1]
  def change
    rename_column :record_histories, :changes, :record_changes
  end
end
