# Managers run the org like owners, without the owner role.
#   The enum order is the rank, guest < member < manager < owner.
#
class AddManagerToOrgRoles < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :org_role, "manager", before: "owner"
  end

  # Postgres cannot drop an enum value, so the type is rebuilt without it
  def down
    execute "UPDATE members SET role = 'member' WHERE role = 'manager'"
    execute "UPDATE invitations SET role = 'member' WHERE role = 'manager'"

    %i[members invitations].each { change_column_default it, :role, nil }
    rename_enum :org_role, :org_role_with_manager
    create_enum :org_role, %w[guest member owner]
    %i[members invitations].each do |table|
      execute "ALTER TABLE #{table} ALTER COLUMN role TYPE org_role USING role::text::org_role"
      change_column_default table, :role, "member"
    end
    drop_enum :org_role_with_manager
  end
end
