# Archiving a project sets archived_at: it stays readable and exportable, but
# takes no new or changed entries. NULL means active.
#
class AddArchivedAtToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :archived_at, :datetime
  end
end
