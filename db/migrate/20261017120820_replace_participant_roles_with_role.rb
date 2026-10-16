# One project role per participant instead of the roles array, like the org role.
#   The UI only ever set one, the strongest of several wins. The enum order is the rank.
#
class ReplaceParticipantRolesWithRole < ActiveRecord::Migration[8.1]
  def up
    create_enum :project_role, %w[observer participant lead]

    add_column :participants, :role, :enum, enum_type: :project_role, default: "participant", null: false
    execute <<~SQL
      UPDATE participants SET role = CASE
        WHEN 'lead' = ANY(roles) THEN 'lead'::project_role
        WHEN 'participant' = ANY(roles) THEN 'participant'::project_role
        ELSE 'observer'::project_role
      END
    SQL
    remove_column :participants, :roles
  end

  def down
    add_column :participants, :roles, :text, array: true, default: [ "participant" ], null: false
    execute "UPDATE participants SET roles = ARRAY[role::text]"
    remove_column :participants, :role

    drop_enum :project_role
  end
end
