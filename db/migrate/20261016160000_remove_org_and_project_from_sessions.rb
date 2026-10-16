# Org and project are part of the path now, a session only signs a user in.
#
class RemoveOrgAndProjectFromSessions < ActiveRecord::Migration[8.0]
  def change
    remove_reference :sessions, :project, null: true, foreign_key: true, type: :uuid, index: true
    remove_reference :sessions, :org, null: true, foreign_key: true, type: :uuid, index: true
  end
end
