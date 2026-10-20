# Access to the MCP server (#108, #109). A connection is one personal access token,
#   or one user's authorization of an OAuth app; its grants name orgs or projects.
#   The oauth_* tables are Doorkeeper's, with uuid keys, a connection on each grant
#   and token, and personal tokens without an application.
#
class CreateConnections < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :oauth_applications, id: :uuid do |t|
      t.string :name, null: false
      t.string :uid, null: false
      t.string :secret # public clients (PKCE) have none
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :confidential, null: false, default: true
      t.timestamps
    end

    create_table :connections, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.references :oauth_application, type: :uuid, foreign_key: true, index: false # nil for a personal token
      t.string :name, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    create_table :connection_grants, id: :uuid do |t|
      t.references :connection, type: :uuid, null: false, foreign_key: true, index: false
      t.references :org, type: :uuid, null: false, foreign_key: true, index: false
      t.references :project, type: :uuid, foreign_key: true, index: false # nil for the whole org
      t.string :access, null: false
      t.timestamps
    end
    add_check_constraint :connection_grants, "access IN ('read', 'write')", name: "connection_grants_access"

    create_table :oauth_access_grants, id: :uuid do |t|
      t.references :resource_owner, type: :uuid, null: false, foreign_key: { to_table: :users }, index: false
      t.references :application, type: :uuid, null: false, foreign_key: { to_table: :oauth_applications }, index: false
      t.references :connection, type: :uuid, null: false, foreign_key: true, index: false
      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.string :code_challenge
      t.string :code_challenge_method
      t.datetime :created_at, null: false
      t.datetime :revoked_at
    end

    create_table :oauth_access_tokens, id: :uuid do |t|
      t.references :resource_owner, type: :uuid, null: false, foreign_key: { to_table: :users }, index: false
      t.references :application, type: :uuid, foreign_key: { to_table: :oauth_applications }, index: false
      t.references :connection, type: :uuid, null: false, foreign_key: true, index: false
      t.string :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.string :scopes
      t.string :previous_refresh_token, null: false, default: ""
      t.datetime :created_at, null: false
      t.datetime :revoked_at
    end

    add_index :oauth_applications, :uid, unique: true, algorithm: :concurrently

    add_index :connections, :user_id, algorithm: :concurrently
    add_index :connections, :oauth_application_id, algorithm: :concurrently

    # one grant per org, and one per project
    add_index :connection_grants, %i[connection_id org_id], unique: true, where: "project_id IS NULL",
      name: "index_connection_grants_on_connection_id_and_org_id", algorithm: :concurrently
    add_index :connection_grants, %i[connection_id project_id], unique: true, where: "project_id IS NOT NULL",
      name: "index_connection_grants_on_connection_id_and_project_id", algorithm: :concurrently
    add_index :connection_grants, :org_id, algorithm: :concurrently
    add_index :connection_grants, :project_id, algorithm: :concurrently

    add_index :oauth_access_grants, :token, unique: true, algorithm: :concurrently
    add_index :oauth_access_grants, :resource_owner_id, algorithm: :concurrently
    add_index :oauth_access_grants, :application_id, algorithm: :concurrently
    add_index :oauth_access_grants, :connection_id, algorithm: :concurrently

    add_index :oauth_access_tokens, :token, unique: true, algorithm: :concurrently
    add_index :oauth_access_tokens, :refresh_token, unique: true, algorithm: :concurrently
    add_index :oauth_access_tokens, :resource_owner_id, algorithm: :concurrently
    add_index :oauth_access_tokens, :application_id, algorithm: :concurrently
    add_index :oauth_access_tokens, :connection_id, algorithm: :concurrently
  end
end
