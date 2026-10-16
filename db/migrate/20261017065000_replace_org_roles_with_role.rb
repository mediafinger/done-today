# One org role per member and invitation instead of the roles array.
#   An owner was always also a member, so the strongest role wins.
#
class ReplaceOrgRolesWithRole < ActiveRecord::Migration[8.1]
  TABLES = %i[members invitations].freeze

  def up
    create_enum :org_role, %w[member owner]

    TABLES.each do |table|
      add_column table, :role, :enum, enum_type: :org_role, default: "member", null: false
      execute "UPDATE #{table} SET role = 'owner' WHERE 'owner' = ANY(roles)"
      remove_column table, :roles
    end
  end

  def down
    TABLES.each do |table|
      add_column table, :roles, :text, array: true, default: [ "member" ], null: false
      execute "UPDATE #{table} SET roles = ARRAY['member', 'owner'] WHERE role = 'owner'"
      remove_column table, :role
    end

    drop_enum :org_role
  end
end
