# Guests are externals: they see only the projects they participate in.
#   The enum order is the rank, guest < member < owner.
#
class AddGuestToOrgRoles < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :org_role, "guest", before: "member"
  end

  # Postgres cannot drop an enum value, so the type is rebuilt without it
  def down
    execute "UPDATE members SET role = 'member' WHERE role = 'guest'"
    execute "UPDATE invitations SET role = 'member' WHERE role = 'guest'"

    %i[members invitations].each { change_column_default it, :role, nil }
    rename_enum :org_role, :org_role_with_guest
    create_enum :org_role, %w[member owner]
    %i[members invitations].each do |table|
      execute "ALTER TABLE #{table} ALTER COLUMN role TYPE org_role USING role::text::org_role"
      change_column_default table, :role, "member"
    end
    drop_enum :org_role_with_guest
  end
end
