# Deactivating a member sets archived_at instead of deleting the row, so their
# entries stay. NULL means active.
#
class AddArchivedAtToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :archived_at, :datetime
  end
end
