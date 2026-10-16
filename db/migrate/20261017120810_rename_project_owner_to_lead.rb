# The project role owner becomes lead, so it no longer shares its name with the org role.
#
class RenameProjectOwnerToLead < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE participants SET roles = array_replace(roles, 'owner', 'lead') WHERE 'owner' = ANY(roles)"
  end

  def down
    execute "UPDATE participants SET roles = array_replace(roles, 'lead', 'owner') WHERE 'lead' = ANY(roles)"
  end
end
