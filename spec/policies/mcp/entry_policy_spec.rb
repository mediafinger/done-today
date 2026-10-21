require "rails_helper"

RSpec.describe Mcp::EntryPolicy do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:lead) { create(:participant, :lead, project:, member: create(:member, :owner, org:)).member }
  let(:connection) { create(:connection, user: lead.user) }

  before { create(:connection_grant, :write, connection:, org:) }

  def scope = described_class.new(nil, connection:).apply_scope(Entry.all, type: :active_record_relation)

  def entry_by(member, project: self.project)
    create(:entry, day: project.days.find_or_create_by!(date: Date.current), member:)
  end

  it "scopes to the own entries, even for an owner who leads the project" do
    own = entry_by(lead)
    entry_by(create(:participant, project:).member)

    expect(scope).to contain_exactly(own)
  end

  it "leaves out own entries of a project the connection doesn't reach" do
    elsewhere = create(:project, org:)
    entry_by(lead, project: elsewhere)

    expect(scope).to be_empty
  end

  it "leaves out everything once the member is archived" do
    entry_by(lead)
    create(:member, :owner, org:)
    lead.archive!

    expect(scope).to be_empty
  end
end
