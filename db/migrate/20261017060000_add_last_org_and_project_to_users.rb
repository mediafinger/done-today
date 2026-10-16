# The org and project a user worked in last, so a new session on any device can
# start there. Nullified rather than blocking when the org or project goes away.
#
class AddLastOrgAndProjectToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :last_org, type: :uuid, null: true, foreign_key: { to_table: :orgs, on_delete: :nullify }
    add_reference :users, :last_project, type: :uuid, null: true, foreign_key: { to_table: :projects, on_delete: :nullify }
  end
end
