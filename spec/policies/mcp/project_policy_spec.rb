require "rails_helper"

RSpec.describe Mcp::ProjectPolicy do
  let(:org) { create(:org) }
  let(:member) { create(:member, org:) }
  let(:connection) { create(:token_auth_connection, user: member.user) }
  let(:writable) { create(:project, org:) }
  let(:readable) { create(:project, org:) }

  before do
    create(:participant, project: writable, member:)
    create(:participant, :observer, project: readable, member:)
    create(:project, org:) # no participation
    create(:token_auth_connection_grant, connection:, org:, access: "write")
  end

  def policy(project) = described_class.new(project, connection:)

  it "reads and writes as TokenAuth::Connection#access_for says" do
    expect([ policy(writable).apply(:read?), policy(writable).apply(:write?) ]).to eq([ true, true ])
    expect([ policy(readable).apply(:read?), policy(readable).apply(:write?) ]).to eq([ true, false ])
  end

  it "scopes to the readable projects" do
    expect(policy(nil).apply_scope(Project.all, type: :active_record_relation)).to contain_exactly(writable, readable)
  end
end
