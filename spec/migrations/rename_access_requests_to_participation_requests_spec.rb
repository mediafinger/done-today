require "rails_helper"
require Rails.root.join("db/migrate/20261021090000_rename_access_requests_to_participation_requests")

RSpec.describe RenameAccessRequestsToParticipationRequests do
  let(:connection) { ActiveRecord::Base.connection }
  let(:project) { create(:project) }
  let(:member) { create(:member, org: project.org) }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  # the DDL runs inside the example's transaction and is rolled back with it
  after { ParticipationRequest.reset_column_information }

  def migrate(direction)
    described_class.new.migrate(direction)
  end

  def requests(table)
    connection.select_rows("SELECT member_id, project_id, message, status::text FROM #{table}")
  end

  before do
    migrate(:down)

    connection.execute(<<~SQL)
      INSERT INTO access_requests (org_id, project_id, member_id, message, created_at, updated_at)
      VALUES (#{connection.quote(project.org_id)}, #{connection.quote(project.id)}, #{connection.quote(member.id)},
              'Please', now(), now())
    SQL
  end

  it "keeps the requests" do
    migrate(:up)

    expect(connection.table_exists?(:access_requests)).to be(false)
    expect(requests(:participation_requests)).to eq([ [ member.id, project.id, "Please", "pending" ] ])
  end

  it "renames the status type and the indexes" do
    migrate(:up)

    enum_types = connection.enum_types.map(&:first)

    expect(enum_types).to include("participation_request_status")
    expect(enum_types).not_to include("access_request_status")
    expect(connection.indexes(:participation_requests).map(&:name)).to all(start_with("index_participation_requests_"))
  end

  it "still allows one pending request per member and project" do
    migrate(:up)

    expect { create(:participation_request, project:, member:) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { build(:participation_request, org: project.org, project:, member:).save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "migrates back" do
    migrate(:up)
    migrate(:down)

    expect(requests(:access_requests)).to eq([ [ member.id, project.id, "Please", "pending" ] ])
  end
end
