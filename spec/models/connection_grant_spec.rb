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

  it "knows read and write only" do
    expect(build(:connection_grant, access: "admin")).not_to be_valid
  end
end
