# The MCP connection a change was made through, nil for the UI. No foreign key, like
#   user_id: the history outlives what it points at.
#
class AddConnectionToRecordHistories < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :record_histories, :connection_id, :uuid
    add_index :record_histories, :connection_id, algorithm: :concurrently
  end
end
