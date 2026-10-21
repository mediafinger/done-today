# Connections and their grants move into the TokenAuth namespace. Renames only, the rows stay.
#
class RenameConnectionsToTokenAuth < ActiveRecord::Migration[8.1]
  def change
    # its default name on the new table would exceed Postgres' 63 characters
    rename_index :connection_grants, "index_connection_grants_on_connection_id_and_project_id",
      "index_connection_grants_on_connection_and_project"

    safety_assured do # not deployed yet, no running app reads the old names
      rename_table :connections, :token_auth_connections
      rename_table :connection_grants, :token_auth_connection_grants

      reversible do |direction|
        direction.up { execute "ALTER TABLE token_auth_connection_grants RENAME CONSTRAINT connection_grants_access TO token_auth_connection_grants_access" }
        direction.down { execute "ALTER TABLE token_auth_connection_grants RENAME CONSTRAINT token_auth_connection_grants_access TO connection_grants_access" }
      end
    end

    rename_index :token_auth_connection_grants, "index_connection_grants_on_connection_and_project",
      "index_token_auth_connection_grants_on_connection_and_project"
  end
end
