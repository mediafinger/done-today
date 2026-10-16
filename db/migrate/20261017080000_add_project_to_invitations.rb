# A guest is invited to one project, with their role in it.
#
class AddProjectToInvitations < ActiveRecord::Migration[8.1]
  def change
    add_reference :invitations, :project, type: :uuid, foreign_key: true
    add_column :invitations, :project_role, :string
  end
end
