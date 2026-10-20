require "rails_helper"

RSpec.describe ConnectionGrant do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:connection) { create(:connection) }

  it "allows one grant for the org and one per project" do
    create(:connection_grant, connection:, org:)
    create(:connection_grant, connection:, org:, project:)

    expect(build(:connection_grant, connection:, org:)).not_to be_valid
    expect(build(:connection_grant, connection:, org:, project:)).not_to be_valid
  end

  it "refuses a project of another org" do
    expect(build(:connection_grant, connection:, org: create(:org), project:)).not_to be_valid
  end

  describe "#effective_access" do
    let(:member) { create(:member, org:, user: connection.user) }

    it "caps a write grant at what the role allows" do
      create(:participant, :observer, project:, member:)

      expect(create(:connection_grant, :write, connection:, org:, project:).effective_access).to eq(:read)
    end

    it "gives an org grant the best access in the projects of the org" do
      create(:participant, :observer, project:, member:)
      create(:participant, project: create(:project, org:), member:)

      expect(create(:connection_grant, :write, connection:, org:).effective_access).to eq(:write)
    end

    it "has no effect once the participation is gone" do
      grant = create(:connection_grant, :write, connection:, org:, project:)

      expect(grant.effective_access).to be_nil
    end
  end

  it "knows read and write only" do
    expect(build(:connection_grant, access: "admin")).not_to be_valid
  end
end
