require "rails_helper"
require Rails.root.join("db/migrate/20261017065000_replace_org_roles_with_role")

RSpec.describe ReplaceOrgRolesWithRole do
  let(:connection) { ActiveRecord::Base.connection }
  let(:org) { create(:org) }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  # the DDL runs inside the example's transaction and is rolled back with it
  after { [ Member, Invitation ].each(&:reset_column_information) }

  def migrate(direction)
    described_class.new.migrate(direction)
    [ Member, Invitation ].each(&:reset_column_information)
  end

  def rows(sql)
    connection.select_all(sql).cast_values
  end

  def insert_member(name, roles)
    connection.execute(<<~SQL)
      INSERT INTO members (org_id, user_id, name, roles, created_at, updated_at)
      VALUES (#{connection.quote(org.id)}, #{connection.quote(create(:user).id)}, #{connection.quote(name)},
              ARRAY[#{roles.map { connection.quote(it) }.join(", ")}]::text[], now(), now())
    SQL
  end

  def insert_invitation(email, roles)
    connection.execute(<<~SQL)
      INSERT INTO invitations (org_id, email, roles, sent_at, created_at, updated_at)
      VALUES (#{connection.quote(org.id)}, #{connection.quote(email)},
              ARRAY[#{roles.map { connection.quote(it) }.join(", ")}]::text[], now(), now(), now())
    SQL
  end

  before do
    org
    migrate(:down)

    insert_member("Owner", %w[member owner])
    insert_member("Owner only", %w[owner])
    insert_member("Member", %w[member])
    insert_invitation("owner@example.com", %w[member owner])
    insert_invitation("member@example.com", %w[member])
  end

  it "makes every member with the owner role an owner, everyone else a member" do
    migrate(:up)

    expect(Member.order(:name).pluck(:name, :role)).to eq(
      [ [ "Member", "member" ], [ "Owner", "owner" ], [ "Owner only", "owner" ] ]
    )
    expect(Invitation.order(:email).pluck(:email, :role)).to eq(
      [ [ "member@example.com", "member" ], [ "owner@example.com", "owner" ] ]
    )
  end

  it "migrates back to the roles arrays" do
    migrate(:up)
    migrate(:down)

    # the models declare the enum, so read the old columns without them
    expect(rows("SELECT name, roles FROM members ORDER BY name")).to eq(
      [ [ "Member", %w[member] ], [ "Owner", %w[member owner] ], [ "Owner only", %w[member owner] ] ]
    )
    expect(rows("SELECT roles FROM invitations ORDER BY email")).to eq([ %w[member], %w[member owner] ])
  end
end
