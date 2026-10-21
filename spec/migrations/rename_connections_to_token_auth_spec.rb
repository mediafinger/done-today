require "rails_helper"
require Rails.root.join("db/migrate/20261021100000_rename_connections_to_token_auth")

RSpec.describe RenameConnectionsToTokenAuth do
  let(:connection) { ActiveRecord::Base.connection }
  let(:user) { create(:user) }
  let(:org) { create(:org) }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  # the DDL runs inside the example's transaction and is rolled back with it
  after do
    TokenAuth::Connection.reset_column_information
    TokenAuth::ConnectionGrant.reset_column_information
  end

  def migrate(direction)
    described_class.new.migrate(direction)
  end

  def index_names(table)
    connection.indexes(table).map(&:name)
  end

  def check_names(table)
    connection.check_constraints(table).map(&:name)
  end

  before do
    migrate(:down)

    connection.execute(<<~SQL)
      INSERT INTO connections (id, user_id, name, created_at, updated_at)
      VALUES ('00000000-0000-0000-0000-000000000001', #{connection.quote(user.id)}, 'Laptop', now(), now());
      INSERT INTO connection_grants (connection_id, org_id, access, created_at, updated_at)
      VALUES ('00000000-0000-0000-0000-000000000001', #{connection.quote(org.id)}, 'write', now(), now());
    SQL
  end

  it "keeps the connections and their grants" do
    migrate(:up)

    expect(connection.table_exists?(:connections)).to be(false)
    expect(connection.table_exists?(:connection_grants)).to be(false)
    expect(connection.select_rows("SELECT name FROM token_auth_connections")).to eq([ [ "Laptop" ] ])
    expect(connection.select_rows("SELECT access FROM token_auth_connection_grants")).to eq([ [ "write" ] ])
  end

  it "renames the indexes and the access check" do
    migrate(:up)

    expect(index_names(:token_auth_connections)).to contain_exactly(
      "index_token_auth_connections_on_user_id", "index_token_auth_connections_on_oauth_application_id"
    )
    expect(index_names(:token_auth_connection_grants)).to contain_exactly(
      "index_token_auth_connection_grants_on_connection_id_and_org_id",
      "index_token_auth_connection_grants_on_connection_and_project",
      "index_token_auth_connection_grants_on_org_id",
      "index_token_auth_connection_grants_on_project_id"
    )
    expect(check_names(:token_auth_connection_grants)).to eq([ "token_auth_connection_grants_access" ])
  end

  it "rolls back to the old names" do
    migrate(:up)
    migrate(:down)

    expect(connection.select_rows("SELECT name FROM connections")).to eq([ [ "Laptop" ] ])
    expect(index_names(:connection_grants)).to include("index_connection_grants_on_connection_id_and_project_id")
    expect(check_names(:connection_grants)).to eq([ "connection_grants_access" ])
  end
end
