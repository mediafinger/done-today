# Postgres prints "access IN (...)" from the migrations differently than the same check loaded
# from db/schema.rb, so a migrated dev DB kept dumping a schema.rb diff. Use the loaded form.
#
class AlignTokenAuthAccessCheck < ActiveRecord::Migration[8.1]
  def change
    safety_assured do # not deployed yet, the table holds no rows
      remove_check_constraint :token_auth_connection_grants, "access IN ('read', 'write')",
        name: "token_auth_connection_grants_access"
      add_check_constraint :token_auth_connection_grants,
        "access::text = ANY (ARRAY['read'::character varying::text, 'write'::character varying::text])",
        name: "token_auth_connection_grants_access"
    end
  end
end
