require "rails_helper"
require Rails.root.join("db/migrate/20261021110000_align_token_auth_access_check")

RSpec.describe AlignTokenAuthAccessCheck do
  let(:connection) { ActiveRecord::Base.connection }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  def migrate(direction)
    described_class.new.migrate(direction)
  end

  def access_check
    connection.check_constraints(:token_auth_connection_grants).sole.expression
  end

  # the test DB is loaded from db/schema.rb, a migrated dev DB must dump the same expression
  it "makes a migrated DB dump the check as db/schema.rb has it" do
    from_schema = access_check
    migrate(:down)
    expect(access_check).not_to eq(from_schema)

    migrate(:up)

    expect(access_check).to eq(from_schema)
  end

  it "still allows only read and write" do
    migrate(:down)
    migrate(:up)

    grant = create(:token_auth_connection_grant)

    expect { grant.update_column(:access, "admin") }
      .to raise_error(ActiveRecord::StatementInvalid, /token_auth_connection_grants_access/)
  end
end
